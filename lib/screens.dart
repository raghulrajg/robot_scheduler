import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:otp/otp.dart';
import 'feedback.dart';
import 'main.dart';

// ==========================================
// 1. OPERATOR LOGIN SCREEN
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  void _login() {
    final user = _usernameCtrl.text.trim();
    final pass = _passwordCtrl.text;

    if (MockDatabase.users.containsKey(user) && MockDatabase.users[user]!['password'] == pass) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SchedulerScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Username or Password')));
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Operator Login')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.precision_manufacturing, size: 80, color: Colors.blue),
            const SizedBox(height: 30),
            TextField(controller: _usernameCtrl, decoration: const InputDecoration(labelText: 'Username')),
            const SizedBox(height: 15),
            TextField(controller: _passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
              child: const Text('Login', style: TextStyle(fontSize: 18)),
            ),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen())),
              child: const Text('Register New Operator'),
            )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. NEW OPERATOR SIGN UP SCREEN
// ==========================================
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  void _verifyAndProceed() {
    final username = _usernameCtrl.text.trim();
    
    if (username.isEmpty || _passwordCtrl.text.isEmpty || _nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields.')));
      return;
    }
    if (MockDatabase.users.containsKey(username)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username exists! Choose another.')));
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (context) => TotpVerificationScreen(
      name: _nameCtrl.text, designation: _designationCtrl.text, username: username, password: _passwordCtrl.text,
    )));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _designationCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Operator Registration')),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
          const SizedBox(height: 15),
          TextField(controller: _designationCtrl, decoration: const InputDecoration(labelText: 'Designation')),
          const SizedBox(height: 15),
          TextField(controller: _usernameCtrl, decoration: const InputDecoration(labelText: 'Username')),
          const SizedBox(height: 15),
          TextField(controller: _passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _verifyAndProceed,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
            child: const Text('Next: Admin Authorization', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. ADMIN TOTP AUTHORIZATION SCREEN
// ==========================================
class TotpVerificationScreen extends StatefulWidget {
  final String name, designation, username, password;
  const TotpVerificationScreen({super.key, required this.name, required this.designation, required this.username, required this.password});
  @override
  State<TotpVerificationScreen> createState() => _TotpVerificationScreenState();
}

class _TotpVerificationScreenState extends State<TotpVerificationScreen> {
  final _totpCtrl = TextEditingController();

  void _authorizeAccount() {
    final userInput = _totpCtrl.text.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Explicitly enforce SHA1 across all windows
    final currentCode = OTP.generateTOTPCodeString(MockDatabase.adminSecretKey.trim(), now, algorithm: Algorithm.SHA1, isGoogle: true);
    final previousCode = OTP.generateTOTPCodeString(MockDatabase.adminSecretKey.trim(), now - 30000, algorithm: Algorithm.SHA1, isGoogle: true);
    final nextCode = OTP.generateTOTPCodeString(MockDatabase.adminSecretKey.trim(), now + 30000, algorithm: Algorithm.SHA1, isGoogle: true);

    if (userInput == currentCode || userInput == previousCode || userInput == nextCode) {
      final newUserPayload = {
        'name': widget.name, 'designation': widget.designation, 'password': widget.password,
      };
      
      // Save directly to device disk so it survives reboots!
      MockDatabase.saveUser(widget.username, newUserPayload).then((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Operator Authorized & Saved!'), backgroundColor: Colors.green));
        Navigator.popUntil(context, (route) => route.isFirst);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid TOTP Code.'), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _totpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Authorization')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Hand device to Admin.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text('Enter the live 6-digit Google Authenticator code.', textAlign: TextAlign.center),
            const SizedBox(height: 30),
            TextField(
              controller: _totpCtrl, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, letterSpacing: 10), decoration: const InputDecoration(counterText: ""),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _authorizeAccount,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 15)),
              child: const Text('Authorize & Create Account', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. FLEET COMMAND DASHBOARD (MQTT)
// ==========================================
class SchedulerScreen extends StatefulWidget {
  const SchedulerScreen({super.key});
  @override
  State<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends State<SchedulerScreen> {
  final TextEditingController _promptController = TextEditingController();
  MqttServerClient? _client;
  bool _isConnected = false;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updates;
  final List<FleetFeedback> _feedback = [];        // newest first
  final Set<String> _myRequests = {};              // request ids sent from this device

  @override
  void initState() {
    super.initState();
    _connectToBroker();
  }

  Future<void> _connectToBroker() async {
    // Plain MQTT over TCP to the broker -- no rosbridge envelope, no "op"
    // wrapper. A unique-ish client id avoids the broker kicking a previous
    // session for the same operator off the connection.
    final clientId = 'flutter_operator_${DateTime.now().millisecondsSinceEpoch}';
    final client = MqttServerClient(MqttConfig.brokerHost, clientId);
    client.port = MqttConfig.brokerPort;
    client.keepAlivePeriod = 60;
    client.autoReconnect = true;            // re-subscribes to hmi/feedback by itself
    client.logging(on: false);
    client.onDisconnected = _onDisconnected;
    client.onAutoReconnected = _onReconnected;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(MqttConfig.username, MqttConfig.password)
        .startClean();
    client.connectionMessage = connMessage;

    _client = client;

    try {
      await client.connect();
    } catch (e) {
      client.disconnect();
      if (!mounted) return;
      setState(() => _isConnected = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('MQTT connection error: $e')));
      return;
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      // Answers to our prompts (understood / rejected / confirm?) and conveyor warnings.
      client.subscribe(MqttConfig.feedbackTopic, MqttQos.atLeastOnce);
      await _updates?.cancel();
      _updates = client.updates?.listen(_onMessages);
      if (!mounted) return;
      setState(() => _isConnected = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connected to Fleet Controller (MQTT)')));
    } else {
      client.disconnect();
      if (!mounted) return;
      setState(() => _isConnected = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('MQTT connection refused by broker.')));
    }
  }

  void _onDisconnected() {
    if (!mounted) return;
    setState(() => _isConnected = false);
  }

  void _onReconnected() {
    if (!mounted) return;
    setState(() => _isConnected = true);
  }

  void _onMessages(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final m in messages) {
      if (m.topic != MqttConfig.feedbackTopic) continue;
      final publish = m.payload as MqttPublishMessage;
      final text = utf8.decode(publish.payload.message, allowMalformed: true);
      final fb = FleetFeedback.parse(text);
      if (fb == null) continue;
      // Prompt feedback is for the operator who sent the prompt; conveyor warnings are for everyone.
      final mine = fb.requestId != null && _myRequests.contains(fb.requestId);
      if (fb.kind != FeedbackKind.conveyorWarning && !mine) continue;
      _showFeedback(fb);
    }
  }

  void _showFeedback(FleetFeedback fb) {
    if (!mounted) return;
    setState(() {
      _feedback.insert(0, fb);
      if (_feedback.length > 30) _feedback.removeLast();
    });
    if (fb.kind == FeedbackKind.needsConfirmation) {
      _askConfirmation(fb);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(fb.text),
      backgroundColor: fb.isProblem ? (fb.kind == FeedbackKind.conveyorWarning ? Colors.orange[800] : Colors.red)
          : (fb.kind == FeedbackKind.forwarded ? Colors.green : null),
      duration: Duration(seconds: fb.isProblem ? 8 : 4),
    ));
  }

  Future<void> _askConfirmation(FleetFeedback fb) async {
    final i = fb.instruction!;
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Run this job?'),
        content: Text('Product: ${i['product']}\n'
            'Pick up at: ${i['source']}\n'
            'Inspect at: ${i['quality_check']}\n'
            'Pass -> ${i['success_dest']}\n'
            'Fail -> ${i['fail_dest']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Discard')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    final client = _client;
    if (confirm == null || client == null || !_isConnected || fb.requestId == null) return;
    final builder = MqttClientPayloadBuilder();
    builder.addUTF8String(confirmPayload(fb.requestId!, confirm));
    client.publishMessage(MqttConfig.confirmTopic, MqttQos.atLeastOnce, builder.payload!);
  }

  void _sendCommand() {
    final client = _client;
    final prompt = _promptController.text.trim();
    if (client != null && _isConnected && prompt.isNotEmpty) {
      // {"prompt", "request_id"} (reasoning_agent.py accepts this as well as plain
      // text): the request id comes back on hmi/feedback with the answer.
      final requestId = 'app${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
      _myRequests.add(requestId);
      final builder = MqttClientPayloadBuilder();
      builder.addUTF8String(promptPayload(prompt, requestId));
      client.publishMessage(MqttConfig.promptTopic, MqttQos.atLeastOnce, builder.payload!);
      _promptController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Command sent, waiting for the agent...')));
    }
  }

  void _logout() {
    _updates?.cancel();
    _client?.disconnect();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  Icon _feedbackIcon(FleetFeedback fb) {
    switch (fb.kind) {
      case FeedbackKind.forwarded:
        return const Icon(Icons.check_circle, color: Colors.green);
      case FeedbackKind.needsConfirmation:
        return const Icon(Icons.help, color: Colors.blue);
      case FeedbackKind.error:
        return const Icon(Icons.error, color: Colors.red);
      case FeedbackKind.conveyorWarning:
        return const Icon(Icons.warning, color: Colors.orange);
      default:
        return const Icon(Icons.info_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet Command'), 
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode), 
            onPressed: () {
              RobotFleetApp.themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            }
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout)
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            TextField(
              controller: _promptController, 
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Task Prompt', 
                hintText: 'e.g. take ABCD from manufacturing_1, inspect it, good parts to package_area',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isConnected ? _sendCommand : _connectToBroker,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20)),
              child: Text(_isConnected ? 'Execute Agentic Workflow' : 'Re-connect to Server'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _feedback.isEmpty
                  ? const Center(child: Text('Answers from the fleet and conveyor warnings appear here.'))
                  : ListView.separated(
                      itemCount: _feedback.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final fb = _feedback[i];
                        final t = fb.time;
                        return ListTile(
                          dense: true,
                          leading: _feedbackIcon(fb),
                          title: Text(fb.text),
                          subtitle: Text('${t.hour.toString().padLeft(2, '0')}:'
                              '${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _updates?.cancel();
    _client?.disconnect();
    _promptController.dispose();
    super.dispose();
  }
}
