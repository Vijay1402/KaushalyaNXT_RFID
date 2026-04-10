package com.example.kaushalyanxt_rfid

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.PrintWriter
import java.io.StringWriter
import com.rscja.deviceapi.RFIDWithUHFBLE
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.util.Log
import com.rscja.deviceapi.entity.UHFTAGInfo
import com.rscja.deviceapi.interfaces.ConnectionStatus
import com.rscja.deviceapi.interfaces.ScanBTCallback
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val channelName = "com.reon.rfid"

    private var reader: RFIDWithUHFBLE? = null
    private var isInitialized: Boolean = false
    private var connectedDeviceAddress: String? = null

    // Bank constants
    private val BANK_RESERVED = 0
    private val BANK_EPC = 1
    private val BANK_TID = 2
    private val BANK_USER = 3

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "isBluetoothEnabled" -> {
                        try {
                            val adapter = BluetoothAdapter.getDefaultAdapter()
                            result.success(adapter?.isEnabled == true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    "scanBleDevices" -> {
                        val timeoutMs = call.argument<Int>("timeoutMs") ?: 5000
                        thread {
                            val devices = scanBleDevicesInternal(timeoutMs)
                            runOnUiThread { result.success(devices) }
                        }
                    }

                    "connectDevice" -> {
                        val deviceAddress = call.argument<String>("deviceAddress") ?: ""
                        if (deviceAddress.isBlank()) {
                            result.error("INVALID_ARGS", "deviceAddress is required", null)
                            return@setMethodCallHandler
                        }
                        thread {
                            try {
                                val ok = connectDeviceInternal(deviceAddress)
                                runOnUiThread { result.success(ok) }
                            } catch (e: Exception) {
                                runOnUiThread { fail(result, "CONNECT_ERROR", "connectDevice", e) }
                            }
                        }
                    }

                    "configureReaderSession" -> {
                        val frequencyMode = call.argument<Int>("frequencyMode") ?: 0x04
                        val multiTagMode  = call.argument<Boolean>("multiTagMode") ?: false
                        try {
                            val ok = configureReaderSessionInternal(frequencyMode, multiTagMode)
                            result.success(ok)
                        } catch (e: Exception) {
                            fail(result, "CONFIG_ERROR", "configureReaderSession", e)
                        }
                    }

                    // ── scanTagIdentity ──────────────────────────────────────
                    // Waits for physical trigger press, inventories the tag,
                    // returns original EPC (= Tree ID) and TID. Nothing is written.
                    "scanTagIdentity" -> {
                        val deviceAddress = call.argument<String>("deviceAddress") ?: ""
                        val timeoutMs     = call.argument<Int>("timeoutMs") ?: 5000
                        val addrToUse = deviceAddress.ifBlank { connectedDeviceAddress }
                        if (addrToUse.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "deviceAddress required", null)
                            return@setMethodCallHandler
                        }
                        thread {
                            try {
                                val payload = scanTagIdentityInternal(addrToUse, timeoutMs.toLong())
                                runOnUiThread { result.success(payload) }
                            } catch (e: Exception) {
                                runOnUiThread { fail(result, "SCAN_TAG_ERROR", "scanTagIdentity", e) }
                            }
                        }
                    }

                    // ── readUserBank ─────────────────────────────────────────
                    // Reads USER bank from the tag identified by its EPC.
                    // Returns userHex + original epc + tid.
                    "readUserBank" -> {
                        val deviceAddress = call.argument<String>("deviceAddress") ?: ""
                        val addrToUse = deviceAddress.ifBlank { connectedDeviceAddress }
                        val targetEpc = call.argument<String>("targetEpc") ?: ""  // optional filter
                        if (addrToUse.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "deviceAddress required", null)
                            return@setMethodCallHandler
                        }
                        thread {
                            try {
                                val payload = readUserBankInternal(addrToUse, targetEpc)
                                runOnUiThread { result.success(payload) }
                            } catch (e: Exception) {
                                runOnUiThread { fail(result, "READ_ERROR", "readUserBank", e) }
                            }
                        }
                    }

                    // ── writeUserBank ────────────────────────────────────────
                    // Writes ONLY the USER bank to the specific tag identified
                    // by targetEpc. The EPC is NEVER changed — it is the
                    // permanent Tree ID.
                    "writeUserBank" -> {
                        val deviceAddress = call.argument<String>("deviceAddress") ?: ""
                        val addrToUse = deviceAddress.ifBlank { connectedDeviceAddress }
                        val hexUserBank = call.argument<String>("hexUserBank") ?: ""
                        // targetEpc = the original EPC returned by scanTagIdentity.
                        // Used to filter so we write to exactly the right tag.
                        val targetEpc = call.argument<String>("targetEpc") ?: ""

                        if (addrToUse.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "deviceAddress required", null)
                            return@setMethodCallHandler
                        }
                        if (hexUserBank.isBlank()) {
                            result.error("INVALID_ARGS", "hexUserBank required", null)
                            return@setMethodCallHandler
                        }

                        thread {
                            try {
                                val ok = writeUserBankInternal(addrToUse, hexUserBank, targetEpc)
                                runOnUiThread { result.success(ok) }
                            } catch (e: Exception) {
                                runOnUiThread { fail(result, "WRITE_ERROR", "writeUserBank", e) }
                            }
                        }
                    }

                    // ── General readData ───────────────────────────────────────
                    // Reads from specified bank with optional filter
                    "readData" -> {
                        val deviceAddress = call.argument<String>("deviceAddress") ?: ""
                        val addrToUse = deviceAddress.ifBlank { connectedDeviceAddress }
                        val bank = call.argument<Int>("bank") ?: 3  // default USER
                        val ptr = call.argument<Int>("ptr") ?: 0
                        val len = call.argument<Int>("len") ?: 43  // words, 86 bytes for USER
                        val pwd = call.argument<String>("pwd") ?: "00000000"
                        val useFilter = call.argument<Boolean>("useFilter") ?: false
                        val filterBank = call.argument<Int>("filterBank") ?: 1  // EPC
                        val filterPtr = call.argument<Int>("filterPtr") ?: 32
                        val filterLen = call.argument<Int>("filterLen") ?: 96  // bits
                        val filterData = call.argument<String>("filterData") ?: ""

                        if (addrToUse.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "deviceAddress required", null)
                            return@setMethodCallHandler
                        }

                        thread {
                            try {
                                val data = readDataInternal(addrToUse, bank, ptr, len, pwd, useFilter, filterBank, filterPtr, filterLen, filterData)
                                runOnUiThread { result.success(data) }
                            } catch (e: Exception) {
                                runOnUiThread { fail(result, "READ_ERROR", "readData", e) }
                            }
                        }
                    }

                    // ── General writeData ──────────────────────────────────────
                    // Writes to specified bank with optional filter
                    "writeData" -> {
                        val deviceAddress = call.argument<String>("deviceAddress") ?: ""
                        val addrToUse = deviceAddress.ifBlank { connectedDeviceAddress }
                        val bank = call.argument<Int>("bank") ?: 3
                        val ptr = call.argument<Int>("ptr") ?: 0
                        val len = call.argument<Int>("len") ?: 43
                        val pwd = call.argument<String>("pwd") ?: "00000000"
                        val data = call.argument<String>("data") ?: ""
                        val useFilter = call.argument<Boolean>("useFilter") ?: false
                        val filterBank = call.argument<Int>("filterBank") ?: 1
                        val filterPtr = call.argument<Int>("filterPtr") ?: 32
                        val filterLen = call.argument<Int>("filterLen") ?: 96
                        val filterData = call.argument<String>("filterData") ?: ""

                        if (addrToUse.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "deviceAddress required", null)
                            return@setMethodCallHandler
                        }
                        if (data.isBlank()) {
                            result.error("INVALID_ARGS", "data required", null)
                            return@setMethodCallHandler
                        }

                        thread {
                            try {
                                val ok = writeDataInternal(addrToUse, bank, ptr, len, pwd, data, useFilter, filterBank, filterPtr, filterLen, filterData)
                                runOnUiThread { result.success(ok) }
                            } catch (e: Exception) {
                                runOnUiThread { fail(result, "WRITE_ERROR", "writeData", e) }
                            }
                        }
                    }

                    // ── Get connection status ───────────────────────────────────
                    "getConnectionStatus" -> {
                        val status = reader?.connectStatus?.name ?: "DISCONNECTED"
                        result.success(status)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ── Reader init ───────────────────────────────────────────────────────────

    private fun ensureReader(): RFIDWithUHFBLE {
        if (reader == null) reader = RFIDWithUHFBLE.getInstance()
        if (!isInitialized) {
            val ok = reader!!.init(applicationContext)
            if (!ok) throw IllegalStateException("RFID reader init failed")

            try { reader!!.setFrequencyMode(0x04) }       catch (_: Exception) {}
            try { reader!!.setPower(33) }                  catch (_: Exception) {}
            try { reader!!.setSupportRssi(true) }          catch (_: Exception) {}
            try { reader!!.setTagFocus(true) }             catch (_: Exception) {}
            try { reader!!.setFastID(false) }              catch (_: Exception) {}
            try { reader!!.setReaderAwaitSleepTime(800) }  catch (_: Exception) {}

            isInitialized = true
        }
        return reader!!
    }

    // ── Connect ───────────────────────────────────────────────────────────────

    private fun connectDeviceInternal(deviceAddress: String): Boolean {
        val r = ensureReader()

        // Avoid reconnect churn; keep current BLE session when already connected.
        if (connectedDeviceAddress == deviceAddress &&
            r.connectStatus == ConnectionStatus.CONNECTED) {
            Log.d("RFID_BLE", "Already connected to $deviceAddress, skipping reconnect")
            return true
        }

        connectedDeviceAddress = deviceAddress
        try { r.stopScanBTDevices() } catch (_: Exception) {}

        repeat(3) { attempt ->
            try { r.connect(deviceAddress) } catch (_: Exception) {}
            if (waitForConnected(r, 2200)) {
                warmupReaderAfterConnect(r)
                return true
            }
            Log.w("RFID_BLE", "Connect attempt ${attempt + 1} failed for $deviceAddress")
        }
        return false
    }

    private fun scanBleDevicesInternal(timeoutMs: Int): List<Map<String, String>> {
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return emptyList()
        if (!adapter.isEnabled) return emptyList()
        val r = ensureReader()
        val devices = LinkedHashMap<String, String>()
        val callback = ScanBTCallback { bluetoothDevice: BluetoothDevice, _, _ ->
            val address = bluetoothDevice.address ?: return@ScanBTCallback
            if (!devices.containsKey(address)) devices[address] = bluetoothDevice.name ?: ""
        }
        val latchMs = timeoutMs.coerceIn(3000, 20000).toLong()
        try { r.stopScanBTDevices() } catch (_: Exception) {}
        r.startScanBTDevices(callback)
        try { Thread.sleep(latchMs) } catch (_: Exception) {}
        try { r.stopScanBTDevices() } catch (_: Exception) {}
        return devices.entries.map { mapOf("address" to it.key, "name" to it.value) }
    }

    private fun configureReaderSessionInternal(frequencyMode: Int, multiTagMode: Boolean): Boolean {
        val r = ensureReader()
        var ok = true
        ok = ok && try { r.setFrequencyMode(frequencyMode) } catch (_: Exception) { false }
        ok = ok && try { r.setTagFocus(!multiTagMode) }      catch (_: Exception) { false }
        try { r.setSupportRssi(true) } catch (_: Exception) {}
        try { r.setPower(33) }         catch (_: Exception) {}
        return ok
    }

    // ── Scan Tag Identity ─────────────────────────────────────────────────────
    // Direct inventory scan (no trigger dependency).
    // Returns the ORIGINAL EPC (Tree ID) and TID. Nothing is ever written here.

    private fun scanTagIdentityInternal(deviceAddress: String, timeoutMs: Long): Map<String, String> {
        val r = ensureReader()
        connectedDeviceAddress = deviceAddress
        if (!connectDeviceInternal(deviceAddress)) throw IllegalStateException("Reader connect failed")

        val boundedTimeout = timeoutMs.coerceIn(3000, 12000)
        val attempts = when {
            boundedTimeout >= 9000 -> 4
            boundedTimeout >= 5000 -> 3
            else -> 2
        }
        val attemptTimeout = (boundedTimeout / attempts).coerceAtLeast(1500)

        var tag: UHFTAGInfo? = null
        for (attempt in 0 until attempts) {
            tag = inventorySingleFromBuffer(r, attemptTimeout)
            val epcCandidate = tag?.getEPC()?.trim().orEmpty()
            if (epcCandidate.isNotEmpty()) {
                break
            }

            Log.w("RFID_SCAN", "scanTagIdentity: no EPC on attempt ${attempt + 1}/$attempts")
            try {
                configureReaderSessionInternal(
                    safeGetFrequency(r).takeIf { it >= 0 } ?: 0x04,
                    false
                )
            } catch (_: Exception) {}
            try { Thread.sleep(180) } catch (_: Exception) {}
        }

        val epc = tag?.getEPC()?.trim() ?: ""
        val tid = tag?.getTid()?.trim() ?: ""
        if (epc.isBlank()) {
            throw IllegalStateException(
                "No EPC detected after $attempts attempts (timeoutMs=$boundedTimeout, connectStatus=${r.getConnectStatus()}, " +
                    "power=${safeGetPower(r)}, freq=${safeGetFrequency(r)})"
            )
        }
        Log.d("RFID_SCAN", "scanTagIdentity → epc=$epc tid=$tid")
        return mapOf("epc" to epc, "tid" to tid)
    }

    // ── Read USER Bank ────────────────────────────────────────────────────────
    // Reads 86 bytes from USER bank. Returns userHex + original epc + tid.
    // If targetEpc is provided, filters to read only from that specific tag.

    private fun readUserBankInternal(deviceAddress: String, targetEpc: String = ""): Map<String, String> {
        val r = ensureReader()
        connectedDeviceAddress = deviceAddress
        if (!connectDeviceInternal(deviceAddress)) throw IllegalStateException("Reader connect failed")

        val requestedEpc = targetEpc.trim().replace(" ", "").uppercase()
        val hasFilter = requestedEpc.isNotBlank()

        // Best-effort TID: inventory once (but never trust it if EPC mismatch).
        var tid = ""
        var epc = ""
        try {
            val tag = inventorySingleFromBuffer(r)
            if (tag != null) {
                val invEpc = tag.getEPC()?.trim()?.replace(" ", "")?.uppercase() ?: ""
                val invTid = tag.getTid()?.trim()?.replace(" ", "")?.uppercase() ?: ""
                if (!hasFilter || invEpc == requestedEpc) {
                    epc = invEpc
                    tid = invTid
                }
            }
        } catch (_: Exception) {}

        if (hasFilter) {
            epc = requestedEpc
        }
        if (epc.isBlank()) throw IllegalStateException("EPC is empty")

        // Read USER bank. Try filtered first; if it returns empty, fall back to unfiltered.
        // This keeps reads reliable on readers/tags where strict EPC filtering can intermittently fail.
        var userHex: String? = null
        if (hasFilter) {
            userHex = try {
                val filterLenBits = requestedEpc.length * 4
                // EPC bank: skip 32 bits (CRC+PC), then match EPC bits.
                r.readData(
                    "00000000",
                    BANK_EPC,
                    32,
                    filterLenBits,
                    requestedEpc,
                    BANK_USER,
                    0,
                    43
                )
            } catch (e: Exception) {
                Log.e("RFID", "readUserBank: filtered read exception: $e")
                null
            }
        }
        if (userHex.isNullOrBlank()) {
            userHex = try {
                Log.w("RFID", "readUserBank: filtered read empty, trying unfiltered fallback")
                r.readData("00000000", BANK_USER, 0, 43)
            } catch (e: Exception) {
                Log.e("RFID", "readUserBank: unfiltered fallback exception: $e")
                null
            }
        }

        Log.d("RFID", "readUserBank epc=$epc userHex.len=${userHex?.length}")
        if (userHex.isNullOrBlank()) {
            throw IllegalStateException(
                "readData returned empty (epc=$epc, bank=$BANK_USER, ptr=0, words=43, filtered=$hasFilter)"
            )
        }

        return mapOf(
            "userHex" to (userHex.uppercase()),
            "epc"     to epc.uppercase(),
            "tid"     to tid.uppercase()
        )
    }

    // ── Write USER Bank ───────────────────────────────────────────────────────
    // Writes ONLY to USER bank of the tag whose EPC matches targetEpc.
    // The EPC is NEVER overwritten — it stays as the permanent Tree ID.
    //
    // Uses the 9-parameter filtered writeData so it targets EXACTLY the right
    // tag even if multiple tags are in range.

    private fun writeUserBankInternal(
        deviceAddress: String,
        hexUserBank: String,
        targetEpc: String         // original EPC from scanTagIdentity
    ): Boolean {
        val normalized = hexUserBank.trim().uppercase()
        if (normalized.length < 4 || normalized.length % 4 != 0) {
            throw IllegalArgumentException("hexUserBank must be multiple of 4 hex chars, got ${normalized.length}")
        }
        val words = normalized.length / 4   // 172 / 4 = 43

        val requestedEpc = targetEpc.trim().replace(" ", "").uppercase()
        val hasFilter = requestedEpc.isNotBlank()

        Log.d("RFID", "writeUserBank: targetEpc=$requestedEpc, words=$words, hex_len=${normalized.length}")
        Log.d("RFID", "writeUserBank: hex_first48=${normalized.substring(0, minOf(48, normalized.length))}")
        Log.d("RFID", "writeUserBank: hex_last48=${normalized.substring(maxOf(0, normalized.length - 48))}")
        
        // Verify the hex contains the treeId in the first 24 chars (12 bytes = 24 hex chars)
        val treeIdHexPortion = normalized.substring(0, minOf(24, normalized.length))
        Log.d("RFID", "writeUserBank: treeId_hex_portion=$treeIdHexPortion")

        // Use filtered write when targetEpc is available so we write to the exact scanned tag.
        val ok = writeDataInternal(
            deviceAddress = deviceAddress,
            bank = BANK_USER,            // USER bank
            ptr = 0,                     // start from word 0
            len = words,                 // 43 words (86 bytes)
            pwd = "00000000",            // access pwd
            data = normalized,           // the hex data
            useFilter = hasFilter,
            filterBank = if (hasFilter) BANK_EPC else 0,
            filterPtr = if (hasFilter) 32 else 0,
            filterLen = if (hasFilter) (requestedEpc.length * 4) else 0,
            filterData = if (hasFilter) requestedEpc else ""
        )

        Log.d("RFID", "writeUserBank: final result=$ok")
        return ok
    }

    // ── General Read Data ─────────────────────────────────────────────────────
    private fun readDataInternal(
        deviceAddress: String,
        bank: Int,
        ptr: Int,
        len: Int,  // words
        pwd: String,
        useFilter: Boolean,
        filterBank: Int,
        filterPtr: Int,
        filterLen: Int,  // bits
        filterData: String
    ): String? {
        val r = ensureReader()
        connectedDeviceAddress = deviceAddress
        if (!connectDeviceInternal(deviceAddress)) throw IllegalStateException("Reader connect failed")

        val data: String?
        if (useFilter) {
            data = r.readData(pwd, filterBank, filterPtr, filterLen, filterData, bank, ptr, len)
        } else {
            data = r.readData(pwd, bank, ptr, len)
        }
        Log.d("RFID", "readData bank=$bank ptr=$ptr len=$len useFilter=$useFilter data.len=${data?.length}")
        return data?.uppercase()
    }

    // ── General Write Data ────────────────────────────────────────────────────
    private fun writeDataInternal(
        deviceAddress: String,
        bank: Int,
        ptr: Int,
        len: Int,  // words
        pwd: String,
        data: String,
        useFilter: Boolean,
        filterBank: Int,
        filterPtr: Int,
        filterLen: Int,  // bits
        filterData: String
    ): Boolean {
        val r = ensureReader()
        connectedDeviceAddress = deviceAddress
        if (!connectDeviceInternal(deviceAddress)) throw IllegalStateException("Reader connect failed")

        val normalized = data.trim().uppercase()
        if (normalized.length % 4 != 0) {
            throw IllegalArgumentException("data must be multiple of 4 hex chars")
        }
        val words = normalized.length / 4
        if (words != len) {
            throw IllegalArgumentException("len ($len) must match data words ($words)")
        }

        val ok: Boolean
        if (useFilter) {
            ok = r.writeData(pwd, filterBank, filterPtr, filterLen, filterData, bank, ptr, len, normalized)
        } else {
            ok = r.writeData(pwd, bank, ptr, len, normalized)
        }
        Log.d("RFID", "writeData bank=$bank ptr=$ptr len=$len useFilter=$useFilter result=$ok")
        return ok
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun inventorySingleFromBuffer(r: RFIDWithUHFBLE, timeoutMs: Long = 3000): UHFTAGInfo? {
        val fromBuffer = try {
            r.startInventoryTag()
            val startedAt = System.currentTimeMillis()
            var tag: UHFTAGInfo? = null
            while (System.currentTimeMillis() - startedAt < timeoutMs) {
                tag = r.readTagFromBuffer()
                if (tag != null && !tag.getEPC().isNullOrBlank()) break
                try { Thread.sleep(60) } catch (_: Exception) {}
            }
            tag
        } finally {
            try { r.stopInventory() } catch (_: Exception) {}
        }
        if (fromBuffer != null && !fromBuffer.getEPC().isNullOrBlank()) return fromBuffer
        return try { r.inventorySingleTag() } catch (_: Exception) { null }
    }

    private fun safeGetPower(r: RFIDWithUHFBLE): Int = try { r.getPower() } catch (_: Exception) { -1 }

    private fun safeGetFrequency(r: RFIDWithUHFBLE): Int = try { r.getFrequencyMode() } catch (_: Exception) { -1 }

    private fun throwableToString(t: Throwable): String {
        val sw = StringWriter()
        t.printStackTrace(PrintWriter(sw))
        return sw.toString()
    }

    private fun fail(result: MethodChannel.Result, code: String, op: String, e: Throwable) {
        val message = "$op failed: ${e::class.java.simpleName}: ${e.message ?: "unknown error"}"
        val details = mapOf(
            "operation" to op,
            "exception" to e::class.java.name,
            "message" to (e.message ?: ""),
            "stackTrace" to throwableToString(e)
        )
        Log.e("RFID_NATIVE", message, e)
        result.error(code, message, details)
    }

    private fun waitForConnected(r: RFIDWithUHFBLE, timeoutMs: Long): Boolean {
        val startedAt = System.currentTimeMillis()
        while (System.currentTimeMillis() - startedAt < timeoutMs) {
            if (r.getConnectStatus() == com.rscja.deviceapi.interfaces.ConnectionStatus.CONNECTED) return true
            try { Thread.sleep(120) } catch (_: Exception) {}
        }
        return false
    }

    private fun warmupReaderAfterConnect(r: RFIDWithUHFBLE) {
        try { r.setPower(33) }         catch (_: Exception) {}
        try { r.setSupportRssi(true) } catch (_: Exception) {}
        try {
            r.startInventoryTag()
            Thread.sleep(600)
        } catch (_: Exception) {} finally {
            try { r.stopInventory() } catch (_: Exception) {}
        }
    }
}
