import 'package:flutter/material.dart';

Future<bool> showAdminNameConfirmationDialog({
  required BuildContext context,
  required String title,
  required String entityLabel,
  required String expectedName,
  required String actionLabel,
  String? warning,
  bool destructive = false,
}) async {
  final normalizedExpected = expectedName.trim();
  if (normalizedExpected.isEmpty) {
    return true;
  }

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _AdminNameConfirmationDialog(
      title: title,
      entityLabel: entityLabel,
      expectedName: normalizedExpected,
      actionLabel: actionLabel,
      warning: warning,
      destructive: destructive,
    ),
  );

  return result ?? false;
}

class _AdminNameConfirmationDialog extends StatefulWidget {
  const _AdminNameConfirmationDialog({
    required this.title,
    required this.entityLabel,
    required this.expectedName,
    required this.actionLabel,
    required this.destructive,
    this.warning,
  });

  final String title;
  final String entityLabel;
  final String expectedName;
  final String actionLabel;
  final String? warning;
  final bool destructive;

  @override
  State<_AdminNameConfirmationDialog> createState() =>
      _AdminNameConfirmationDialogState();
}

class _AdminNameConfirmationDialogState
    extends State<_AdminNameConfirmationDialog> {
  final TextEditingController _controller = TextEditingController();

  bool get _matches =>
      _controller.text.trim().toLowerCase() ==
      widget.expectedName.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirmButton = ElevatedButton(
      onPressed: _matches ? () => Navigator.pop(context, true) : null,
      style: widget.destructive
          ? ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            )
          : null,
      child: Text(widget.actionLabel),
    );

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.warning ??
                'To continue, type the exact ${widget.entityLabel} name below.',
          ),
          const SizedBox(height: 12),
          SelectableText(
            widget.expectedName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Type: ${widget.expectedName}',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        _matches
            ? confirmButton
            : Tooltip(
                message: 'Type "${widget.expectedName}" to enable',
                child: confirmButton,
              ),
      ],
    );
  }
}
