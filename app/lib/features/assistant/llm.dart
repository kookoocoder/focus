import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'tools.dart';

const _buildKey = String.fromEnvironment('DEEPSEEK_API_KEY');
const _model = String.fromEnvironment(
  'DEEPSEEK_MODEL',
  defaultValue: 'deepseek-chat',
);

/// DeepSeek key entered in the chat (secure storage), else the build one.
class AssistantKey {
  static const _s = FlutterSecureStorage();
  static const _k = 'deepseek_key';
  static String _key = _buildKey;
  static bool custom = false;

  static Future<void> load() async {
    final k = await _s.read(key: _k);
    custom = k != null && k.isNotEmpty;
    _key = custom ? k! : _buildKey;
  }

  static Future<void> save(String k) async {
    await _s.write(key: _k, value: k.trim());
    await load();
  }

  static Future<void> clear() async {
    await _s.delete(key: _k);
    await load();
  }

  static String get masked =>
      _key.length < 12 ? '' : '${_key.substring(0, 5)}…${_key.substring(_key.length - 4)}';
}

bool get assistantConfigured => AssistantKey._key.isNotEmpty;

/// Runs the tool-calling loop. [history] holds OpenAI-format (DeepSeek) messages and is
/// extended in place. Returns the reply text and whether any tool changed data.
Future<(String, bool)> askAssistant(
  List<Map<String, dynamic>> history,
  void Function(String status) onStatus,
) async {
  var changed = false;
  final system =
      'You are the personal agent inside the Focus app, working for one user. '
      'Always address him as "boss". The app manages attendance, GATE prep, '
      'diet, gym, reminders/alarms and scroll control, and you have full '
      'control of it: when the boss asks for something, do it with your tools '
      'right away instead of explaining how. Chain as many tools as needed. '
      'Prefer the specific tools; use list_data/read_data/write_data for '
      'anything else stored on the device (read a key before writing it and '
      'keep its shape). Never invent data. Only ask first before deleting or '
      'overwriting a lot. Replies are often read aloud: keep them short, '
      'plain sentences, no markdown or lists. Now is '
      '${DateTime.now()} (${const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][DateTime.now().weekday - 1]}).';
  final messages = [
    {'role': 'system', 'content': system},
    ...history,
  ];
  for (var turn = 0; turn < 12; turn++) {
    final res = await http.post(
      Uri.parse('https://api.deepseek.com/chat/completions'),
      headers: {
        'authorization': 'Bearer ${AssistantKey._key}',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 1024,
        'tools': [for (final t in assistantTools) t.toSchema()],
        'messages': messages,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final msg = (body['choices'][0]['message'] as Map).cast<String, dynamic>();
    final calls = (msg['tool_calls'] as List? ?? []).cast<Map>();
    final reply = {
      'role': 'assistant',
      'content': msg['content'] ?? '',
      if (calls.isNotEmpty) 'tool_calls': calls,
    };
    messages.add(reply);
    history.add(reply);
    if (calls.isEmpty) return ('${msg['content'] ?? ''}', changed);
    for (final c in calls) {
      final name = '${c['function']['name']}';
      onStatus('Running $name…');
      String out;
      try {
        final tool = assistantTools.firstWhere((t) => t.name == name);
        final raw = '${c['function']['arguments'] ?? ''}';
        final args = raw.trim().isEmpty ? <String, dynamic>{} : jsonDecode(raw);
        final r = await tool.run((args as Map).cast<String, dynamic>());
        if (tool.mutates) changed = true;
        out = jsonEncode(r);
      } catch (e) {
        out = 'error: $e';
      }
      final result = {'role': 'tool', 'tool_call_id': c['id'], 'content': out};
      messages.add(result);
      history.add(result);
    }
  }
  return ('Stopped after too many steps.', changed);
}
