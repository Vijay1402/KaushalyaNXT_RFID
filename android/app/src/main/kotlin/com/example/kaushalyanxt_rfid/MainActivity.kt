package com.example.kaushalyanxt_rfid

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.rscja.deviceapi.RFIDWithUHFBLE
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.util.Log
import com.rscja.deviceapi.entity.UHFTAGInfo
import com.rscja.deviceapi.interfaces.ScanBTCallback
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val channelName = "com.reon.rfid"

    private var reader: RFIDWithUHFBLE? = null
    private var isInitialized: Boolean = false
    private var connectedDeviceAddress: String? = null
    @Volatile private var triggerPressed: Boolean = false

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
                                runOnUiThread { result.error("CONNECT_ERROR", e.message, null) }
                            }
                        }
                    }

                    "configureReaderSession" -> {
                        val frequencyMode = call.argument<Int>("frequencyMode") ?: 0x04
                        val multiTagMode = call.argument<Boolean>("multiTagMode") ?: false
                        try {
                            val ok = configureReaderSessionInternal(frequencyMode, multiTagMode)
                            result.success(ok)
                        } catch (e: Exception) {
                            result.error("CONFIG_ERROR", e.message, null)
                        }
                    }

                    "readUserBank" -> {
                        val deviceAddress = call.argument<String>("deviceAddress") ?: ""
                        val addrToUse = if (deviceAddress.isBlank()) {
                            connectedDeviceAddress
                        } else {
                            deviceAddress
                        }
                        if (addrToUse.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "deviceAddress is required (or connectDevice first)", null)
                            return@setMethodCallHandler
                        }

                        thread {
                            try {
                                val payload = readUserBankInternal(addrToUse)
                                runOnUiThread { result.success(payload) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("READ_ERROR", e.message, null) }
                            }
                        }
                    }

                    "scanTagIdentity" -> {
                        val deviceAddress = call.argument<String>("deviceAddress") ?: ""
                        val timeoutMs = call.argument<Int>("timeoutMs") ?: 5000
                        val addrToUse = if (deviceAddress.isBlank()) {
                            connectedDeviceAddress
                        } else {
                            deviceAddress
                        }
                        if (addrToUse.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "deviceAddress is required (or connectDevice first)", null)
                            return@setMethodCallHandler
                        }
                        thread {
                            try {
                                val payload = scanTagIdentityInternal(addrToUse, timeoutMs.toLong())
                                runOnUiThread { result.success(payload) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("SCAN_TAG_ERROR", e.message, null) }
                            }
                        }
                    }

                    "writeUserBank" -> {
                        val deviceAddress = call.argument<String>("deviceAddress") ?: ""
                        val addrToUse = if (deviceAddress.isBlank()) {
                            connectedDeviceAddress
                        } else {
                            deviceAddress
                        }
                        val hexUserBank = call.argument<String>("hexUserBank") ?: ""
                        val newEpcHex = call.argument<String>("newEpcHex") ?: ""

                        if (addrToUse.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "deviceAddress is required (or connectDevice first)", null)
                            return@setMethodCallHandler
                        }
                        if (hexUserBank.isBlank()) {
                            result.error("INVALID_ARGS", "hexUserBank is required", null)
                            return@setMethodCallHandler
                        }

                        thread {
                            try {
                                val ok = writeUserBankInternal(addrToUse, hexUserBank, newEpcHex)
                                runOnUiThread { result.success(ok) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("WRITE_ERROR", e.message, null) }
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun ensureReader(): RFIDWithUHFBLE {
        if (reader == null) {
            reader = RFIDWithUHFBLE.getInstance()
        }
        if (!isInitialized) {
            val ok = reader!!.init(applicationContext)
            if (!ok) throw IllegalStateException("RFID reader init failed")

            // Match demo setup defaults as closely as possible.
            // UHFSetFragment shows Europe mode as 0x04.
            try {
                reader!!.setFrequencyMode(0x04)
            } catch (_: Exception) {
                // If the SDK/device rejects the value, continue anyway.
            }
            try {
                reader!!.setPower(30)
            } catch (_: Exception) {
                // ignore
            }
            try {
                reader!!.setSupportRssi(true)
            } catch (_: Exception) {
                // ignore
            }

            // Help ensure we effectively inventory only one tag (best RSSI / focused tag).
            try {
                reader!!.setTagFocus(true)
            } catch (_: Exception) {
                // ignore
            }
            try {
                reader!!.setFastID(false)
            } catch (_: Exception) {
                // ignore
            }

            // Reduce wait time for inventory so "scan tag" doesn't hang.
            try {
                // Value is in milliseconds for how long the reader waits internally.
                reader!!.setReaderAwaitSleepTime(800)
            } catch (_: Exception) {
                // ignore if not supported by this SDK version
            }

            // Trigger handling similar to demo app.
            try {
                reader!!.setKeyEventCallback(object : com.rscja.deviceapi.interfaces.KeyEventCallback {
                    override fun onKeyDown(keycode: Int) {
                        triggerPressed = true
                        Log.d("RFID_TRIGGER", "TRIGGER PRESSED key=$keycode")
                    }

                    override fun onKeyUp(keycode: Int) {
                        triggerPressed = false
                        Log.d("RFID_TRIGGER", "TRIGGER RELEASED key=$keycode")
                    }
                })
            } catch (_: Exception) {
                // ignore if this reader model does not expose trigger callbacks
            }

            isInitialized = true
        }
        return reader!!
    }

    private fun connectDeviceInternal(deviceAddress: String): Boolean {
        val r = ensureReader()
        connectedDeviceAddress = deviceAddress

        // Match demo pattern: stop any scan before connect.
        try {
            r.stopScanBTDevices()
        } catch (_: Exception) {
            // ignore
        }

        // Try connect with a few retries because status transition can be slow.
        repeat(3) { attempt ->
            try {
                r.connect(deviceAddress)
            } catch (_: Exception) {
                // ignore and rely on status polling below
            }

            if (waitForConnected(r, timeoutMs = 2200)) {
                // Demo performs a short RF warm-up right after connect.
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
        val devices = LinkedHashMap<String, String>() // address -> name

        val callback = ScanBTCallback { bluetoothDevice: BluetoothDevice, _, _ ->
            val address = bluetoothDevice.address ?: return@ScanBTCallback
            if (!devices.containsKey(address)) {
                devices[address] = bluetoothDevice.name ?: ""
            }
        }

        val latchMs = timeoutMs.coerceIn(3000, 20000).toLong()
        try {
            r.stopScanBTDevices()
        } catch (_: Exception) {
            // ignore
        }
        Log.d("RFID_BLE", "Starting SDK BT scan for ${latchMs}ms")
        r.startScanBTDevices(callback)

        // Block the background thread until timeout, then stop scanning.
        try {
            Thread.sleep(latchMs)
        } catch (_: Exception) {
            // ignore
        }
        try {
            r.stopScanBTDevices()
        } catch (_: Exception) {
            // ignore
        }

        Log.d("RFID_BLE", "SDK BT scan finished. Found=${devices.size}")

        return devices.entries.map { entry ->
            mapOf(
                "address" to entry.key,
                "name" to entry.value
            )
        }
    }

    private fun configureReaderSessionInternal(
        frequencyMode: Int,
        multiTagMode: Boolean
    ): Boolean {
        val r = ensureReader()
        var ok = true

        // Frequency region chosen by user each session.
        ok = ok && try {
            r.setFrequencyMode(frequencyMode)
        } catch (_: Exception) {
            false
        }

        // Single-tag mode: focus on strongest/closest tag.
        // Multi-tag mode: broader inventory behavior.
        ok = ok && try {
            r.setTagFocus(!multiTagMode)
        } catch (_: Exception) {
            false
        }

        // Keep stable defaults.
        try {
            r.setSupportRssi(true)
        } catch (_: Exception) {
        }
        try {
            r.setPower(30)
        } catch (_: Exception) {
        }

        return ok
    }

    private fun readUserBankInternal(deviceAddress: String): Map<String, String> {
        val r = ensureReader()

        // Connect to the BLE UHF reader using its MAC/device address.
        connectedDeviceAddress = deviceAddress
        if (!connectDeviceInternal(deviceAddress)) {
            throw IllegalStateException("Reader connect failed")
        }

        // Inventory to get EPC/TID (tag identity) using demo-like flow.
        val tag = inventorySingleFromBuffer(r)
            ?: throw IllegalStateException("No tag found during inventory")
        val epc = tag.getEPC() ?: ""
        val tid = tag.getTid() ?: ""
        if (epc.isBlank()) throw IllegalStateException("EPC is empty")

        // Read USER memory:
        // In demo app USER bank is index 3.
        // startWord=0, lengthWords=43 -> 43*2 bytes = 86 bytes = 172 hex chars
        val userHex = r.readData(epc, 3, 0, 43)
        return mapOf(
            "userHex" to userHex,
            "epc" to epc,
            "tid" to tid
        )
    }

    private fun scanTagIdentityInternal(
        deviceAddress: String,
        timeoutMs: Long
    ): Map<String, String> {
        val r = ensureReader()
        connectedDeviceAddress = deviceAddress
        if (!connectDeviceInternal(deviceAddress)) {
            throw IllegalStateException("Reader connect failed")
        }

        val startedAt = System.currentTimeMillis()
        var tag: UHFTAGInfo? = null
        val boundedTimeout = timeoutMs.coerceIn(800, 12000)

        // Wait for scanner trigger press first.
        triggerPressed = false
        while (System.currentTimeMillis() - startedAt < boundedTimeout && !triggerPressed) {
            try {
                Thread.sleep(40)
            } catch (_: Exception) {
                // ignore
            }
        }

        val inventoryStartedAt = System.currentTimeMillis()
        while (
            System.currentTimeMillis() - inventoryStartedAt < boundedTimeout &&
            triggerPressed
        ) {
            tag = inventorySingleFromBuffer(r, 700)
            if (tag != null && !tag.getEPC().isNullOrBlank()) {
                break
            }
            try {
                Thread.sleep(120)
            } catch (_: Exception) {
                // ignore
            }
        }

        val epc = tag?.getEPC() ?: ""
        val tid = tag?.getTid() ?: ""
        return mapOf(
            "epc" to epc,
            "tid" to tid
        )
    }

    private fun writeUserBankInternal(
        deviceAddress: String,
        hexUserBank: String,
        newEpcHex: String
    ): Boolean {
        val r = ensureReader()

        connectedDeviceAddress = deviceAddress
        if (!connectDeviceInternal(deviceAddress)) {
            throw IllegalStateException("Reader connect failed before write")
        }

        val tag = inventorySingleFromBuffer(r) ?: return false
        val epcOld = tag.getEPC() ?: return false

        // Write USER memory with the same method as demo app:
        // writeData("00000000", 3, 0, words, data)
        val normalized = hexUserBank.trim().uppercase()
        if (normalized.length < 4 || normalized.length % 4 != 0) return false
        val words = normalized.length / 4
        val userOk = r.writeData("00000000", 3, 0, words, normalized)
        if (!userOk) {
            throw IllegalStateException(
                "writeData returned false (bank=3, ptr=0, words=$words, pwd=00000000)"
            )
        }

        // Also write EPC so "Tree ID" is stored inside EPC (12B).
        // If newEpcHex is blank, we keep the current EPC.
        val epcTrim = newEpcHex.trim()
        if (epcTrim.isEmpty()) return true

        // SDK expects EPC as hex string.
        // Do not fail USER write result if EPC update alone fails.
        return try {
            r.writeDataToEpc(epcOld, epcTrim.uppercase())
            true
        } catch (_: Exception) {
            true
        }
    }

    private fun inventorySingleFromBuffer(
        r: RFIDWithUHFBLE,
        timeoutMs: Long = 1500
    ): UHFTAGInfo? {
        val fromBuffer = try {
            r.startInventoryTag()
            val startedAt = System.currentTimeMillis()
            var tag: UHFTAGInfo? = null

            while (System.currentTimeMillis() - startedAt < timeoutMs) {
                tag = r.readTagFromBuffer()
                if (tag != null && !tag.getEPC().isNullOrBlank()) {
                    break
                }
                try {
                    Thread.sleep(60)
                } catch (_: Exception) {
                    // ignore
                }
            }
            tag
        } finally {
            try {
                r.stopInventory()
            } catch (_: Exception) {
                // ignore
            }
        }
        if (fromBuffer != null && !fromBuffer.getEPC().isNullOrBlank()) {
            return fromBuffer
        }

        // Fallback for some devices that respond better to single shot inventory.
        return try {
            r.inventorySingleTag()
        } catch (_: Exception) {
            null
        }
    }

    private fun waitForConnected(
        r: RFIDWithUHFBLE,
        timeoutMs: Long
    ): Boolean {
        val startedAt = System.currentTimeMillis()
        while (System.currentTimeMillis() - startedAt < timeoutMs) {
            if (r.getConnectStatus() == com.rscja.deviceapi.interfaces.ConnectionStatus.CONNECTED) {
                return true
            }
            try {
                Thread.sleep(120)
            } catch (_: Exception) {
                // ignore
            }
        }
        return false
    }

    private fun warmupReaderAfterConnect(r: RFIDWithUHFBLE) {
        try {
            r.setPower(30)
        } catch (_: Exception) {
        }
        try {
            r.setSupportRssi(true)
        } catch (_: Exception) {
        }
        try {
            r.startInventoryTag()
            Thread.sleep(600)
        } catch (_: Exception) {
        } finally {
            try {
                r.stopInventory()
            } catch (_: Exception) {
            }
        }
    }
}
