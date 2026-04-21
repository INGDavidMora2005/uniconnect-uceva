import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/crypto_service.dart';
import '../services/key_service.dart';

class CryptoTestScreen extends StatefulWidget {
  const CryptoTestScreen({super.key});

  @override
  State<CryptoTestScreen> createState() => _CryptoTestScreenState();
}

class _CryptoTestScreenState extends State<CryptoTestScreen> {
  final TextEditingController _textController = TextEditingController(
    text: 'MiContraseña@UCEVA123',
  );

  String? _rsaPublicKey;
  String? _rsaPrivateKey;
  String? _encryptedData;
  String? _iv;
  String? _encryptedKey;
  String? _decryptedData;
  bool? _matchResult;
  Duration? _lastOperationTime;
  EncryptedPayload? _lastPayload;
  List<String> _sessionIVs = [];
  String? _loginFlowResult;
  String? _externalDecryptedResult;
  bool? _externalDecryptSuccess;
  final TextEditingController _externalCiphertextController =
      TextEditingController();
  final TextEditingController _externalIvController = TextEditingController();
  final TextEditingController _externalKeyController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _verifyRSAKeys() async {
    final stopwatch = Stopwatch()..start();
    try {
      final keyService = KeyService();
      final publicKey = await keyService.getPublicKey();
      final privateKey = await keyService.getPrivateKey();
      stopwatch.stop();

      final modStr = publicKey.modulus!.toRadixString(16);
      final displayMod =
          '${modStr.substring(0, 20)}...${modStr.substring(modStr.length - 20)}';

      setState(() {
        _rsaPublicKey = displayMod;
        _rsaPrivateKey =
            '${privateKey.privateExponent!.toRadixString(16).substring(0, 20)}...';
        _lastOperationTime = stopwatch.elapsed;
      });

      debugPrint('[CryptoTest] ===== VERIFICACIÓN CLAVES RSA =====');
      debugPrint('[CryptoTest] Módulo RSA completo: $modStr');
      debugPrint('[CryptoTest] Exponente público: ${publicKey.exponent}');
      debugPrint(
        '[CryptoTest] Exponente privado: ${privateKey.privateExponent!.toRadixString(16)}',
      );
      debugPrint('[CryptoTest] ======================================');
    } catch (e) {
      debugPrint('[CryptoTest] Error al verificar claves RSA: $e');
    }
  }

  Future<void> _encryptWithRSA() async {
    final stopwatch = Stopwatch()..start();
    try {
      final cryptoService = CryptoService();
      final payload = await cryptoService.encryptPassword(_textController.text);
      stopwatch.stop();

      setState(() {
        _encryptedData = payload.ciphertext;
        _iv = payload.iv;
        _encryptedKey = payload.encryptedKey;
        _lastPayload = payload;
        _lastOperationTime = stopwatch.elapsed;
        _decryptedData = null;
        _matchResult = null;
      });

      debugPrint('[CryptoTest] ===== CIFRADO AES+RSA =====');
      debugPrint('[CryptoTest] Texto original: ${_textController.text}');
      debugPrint('[CryptoTest] Ciphertext (AES): ${payload.ciphertext}');
      debugPrint('[CryptoTest] IV (16 bytes): ${payload.iv}');
      debugPrint('[CryptoTest] EncryptedKey (RSA): ${payload.encryptedKey}');
      debugPrint('[CryptoTest] ===========================');
    } catch (e) {
      debugPrint('[CryptoTest] Error al cifrar: $e');
    }
  }

  Future<void> _decrypt() async {
    if (_lastPayload == null) return;

    final stopwatch = Stopwatch()..start();
    try {
      final cryptoService = CryptoService();
      final decrypted = await cryptoService.decryptPassword(_lastPayload!);
      stopwatch.stop();

      final match = decrypted == _textController.text;

      setState(() {
        _decryptedData = decrypted;
        _matchResult = match;
        _lastOperationTime = stopwatch.elapsed;
      });

      debugPrint('[CryptoTest] ===== DESCIFRADO =====');
      debugPrint('[CryptoTest] Texto descifrado: $decrypted');
      debugPrint(
        '[CryptoTest] Comparación: ${match ? "COINCIDE ✓" : "NO COINCIDE ✗"}',
      );
      debugPrint('[CryptoTest] ====================');
    } catch (e) {
      debugPrint('[CryptoTest] Error al descifrar: $e');
    }
  }

  Future<void> _multiSessionTest() async {
    final stopwatch = Stopwatch()..start();
    final cryptoService = CryptoService();
    final ivs = <String>[];

    try {
      for (int i = 0; i < 3; i++) {
        final payload = await cryptoService.encryptPassword(
          _textController.text,
        );
        ivs.add(payload.iv);
      }
      stopwatch.stop();

      final allDifferent =
          ivs[0] != ivs[1] && ivs[1] != ivs[2] && ivs[0] != ivs[2];

      setState(() {
        _sessionIVs = ivs;
        _lastOperationTime = stopwatch.elapsed;
      });

      debugPrint('[CryptoTest] ===== PRUEBA MULTI-SESIÓN =====');
      debugPrint('[CryptoTest] IV sesión 1: ${ivs[0]}');
      debugPrint('[CryptoTest] IV sesión 2: ${ivs[1]}');
      debugPrint('[CryptoTest] IV sesión 3: ${ivs[2]}');
      debugPrint(
        '[CryptoTest] ¿Todos distintos?: ${allDifferent ? "SÍ ✓" : "NO ✗"}',
      );
      debugPrint('[CryptoTest] ==============================');
    } catch (e) {
      debugPrint('[CryptoTest] Error en prueba multi-sesión: $e');
    }
  }

  Future<void> _simulateLoginFlow() async {
    final stopwatch = Stopwatch()..start();
    try {
      final cryptoService = CryptoService();

      debugPrint('[CryptoTest] ===== SIMULACIÓN FLUJO LOGIN =====');
      debugPrint('[CryptoTest] Paso 1: Cifrar contraseña...');

      final payload = await cryptoService.encryptPassword(_textController.text);

      debugPrint('[CryptoTest] Paso 2: Serializar a JSON...');
      final jsonString = payload.toJson();

      debugPrint('[CryptoTest] Paso 3: JSON serializado: $jsonString');
      debugPrint('[CryptoTest] Paso 4: Deserializar desde JSON...');
      final deserialized = EncryptedPayload.fromJson(jsonString);

      debugPrint('[CryptoTest] Paso 5: Descifrar payload...');
      final decrypted = await cryptoService.decryptPassword(deserialized);

      stopwatch.stop();

      final success = decrypted == _textController.text;

      setState(() {
        _loginFlowResult = success
            ? 'FLUJO COMPLETO EXITOSO\nTexto original: ${_textController.text}\nTexto recuperado: $decrypted'
            : 'ERROR: Los textos no coinciden';
        _lastOperationTime = stopwatch.elapsed;
      });

      debugPrint(
        '[CryptoTest] Paso 6: Verificación final: ${success ? "ÉXITO ✓" : "FALLO ✗"}',
      );
      debugPrint('[CryptoTest] =================================');
    } catch (e) {
      debugPrint('[CryptoTest] Error en simulación login: $e');
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiado al portapapeles'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  void _copyCurrentToExternalFields() {
    if (_encryptedData == null || _iv == null || _encryptedKey == null) return;
    setState(() {
      _externalCiphertextController.text = _encryptedData!;
      _externalIvController.text = _iv!;
      _externalKeyController.text = _encryptedKey!;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Datos copiados a campos externos'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  Future<void> _decryptExternal() async {
    final ciphertext = _externalCiphertextController.text.trim();
    final iv = _externalIvController.text.trim();
    final encryptedKey = _externalKeyController.text.trim();

    if (ciphertext.isEmpty || iv.isEmpty || encryptedKey.isEmpty) {
      setState(() {
        _externalDecryptedResult = '✗ ERROR: Completar todos los campos';
        _externalDecryptSuccess = false;
      });
      return;
    }

    try {
      final payload = EncryptedPayload(
        ciphertext: ciphertext,
        iv: iv,
        encryptedKey: encryptedKey,
      );
      final cryptoService = CryptoService();
      final decrypted = await cryptoService.decryptPassword(payload);
      setState(() {
        _externalDecryptedResult = '✓ DESCIFRADO: $decrypted';
        _externalDecryptSuccess = true;
      });
    } catch (e) {
      setState(() {
        _externalDecryptedResult =
            '✗ ERROR: No se pudo descifrar. La clave privada de este dispositivo no corresponde al ciphertext.';
        _externalDecryptSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text(
          '🧪 Crypto Test Console',
          style: TextStyle(
            color: Color(0xFF00FF00),
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildConsoleOutput(
              'STATUS RSA',
              _rsaPublicKey != null
                  ? 'Clave Pública (módulo): $_rsaPublicKey\nClave Privada (d): $_rsaPrivateKey'
                  : 'Aún no se han verificado las claves',
              showCopy: false,
            ),
            const SizedBox(height: 12),
            _buildButton('Verificar claves RSA', _verifyRSAKeys, Colors.cyan),

            const SizedBox(height: 20),
            const Divider(color: Color(0xFF333333)),
            const SizedBox(height: 20),

            _buildConsoleOutput('TEXTO A CIFRAR', _textController.text),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              style: const TextStyle(
                color: Color(0xFF00FF00),
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0D0D0D),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green.shade700),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green.shade700),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF00FF00)),
                ),
                labelText: 'Texto de prueba',
                labelStyle: TextStyle(color: Colors.green.shade400),
              ),
            ),
            const SizedBox(height: 12),
            _buildButton('Cifrar con AES+RSA', _encryptWithRSA, Colors.orange),

            if (_encryptedData != null) ...[
              const SizedBox(height: 20),
              _buildConsoleOutputWithCopy(
                'CIPHERTEXT (AES)',
                _encryptedData!,
                'Ciphertext',
              ),
              const SizedBox(height: 8),
              _buildConsoleOutputWithCopy('IV', _iv!, 'IV'),
              const SizedBox(height: 8),
              _buildConsoleOutputWithCopy(
                'ENCRYPTED KEY (RSA)',
                _encryptedKey!,
                'EncryptedKey',
              ),
              const SizedBox(height: 12),
              _buildButton('Descifrar', _decrypt, Colors.green),
              const SizedBox(height: 8),
              _buildCopyToExternalButton(),
            ],

            if (_decryptedData != null) ...[
              const SizedBox(height: 12),
              _buildConsoleOutput('TEXTO DESCIFRADO', _decryptedData!),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _matchResult == true
                      ? Colors.green.shade900.withValues(alpha: 0.3)
                      : Colors.red.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _matchResult == true ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _matchResult == true ? Icons.check_circle : Icons.cancel,
                      color: _matchResult == true ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _matchResult == true ? 'COINCIDE ✓' : 'NO COINCIDE ✗',
                      style: TextStyle(
                        color: _matchResult == true ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            const Divider(color: Color(0xFF333333)),
            const SizedBox(height: 20),

            _buildButton(
              'Prueba multi-sesión',
              _multiSessionTest,
              Colors.purple,
            ),

            if (_sessionIVs.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildConsoleOutput(
                'RESULTADO PRUEBA SESIONES',
                'IV 1: ${_sessionIVs[0]}\nIV 2: ${_sessionIVs[1]}\nIV 3: ${_sessionIVs[2]}\n\n${(_sessionIVs[0] != _sessionIVs[1] && _sessionIVs[1] != _sessionIVs[2] && _sessionIVs[0] != _sessionIVs[2]) ? "✓ Todos los IVs son distintos (aleatoriedad OK)" : "✗ Los IVs se repiten"}',
              ),
            ],

            const SizedBox(height: 20),
            _buildButton(
              'Simular flujo login',
              _simulateLoginFlow,
              Colors.teal,
            ),

            if (_loginFlowResult != null) ...[
              const SizedBox(height: 12),
              _buildConsoleOutput('RESULTADO FLUJO LOGIN', _loginFlowResult!),
            ],

            if (_lastOperationTime != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '⏱️ Última operación: ${_lastOperationTime!.inMilliseconds} ms',
                  style: const TextStyle(
                    color: Colors.lightBlue,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 40),
            const Divider(color: Color(0xFF333333)),
            const SizedBox(height: 20),

            _buildConsoleOutput(
              'VERIFICAR CIPHERTEXT EXTERNO',
              'Ingresa un ciphertext generado por este dispositivo para verificar',
              showCopy: false,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _externalCiphertextController,
              style: const TextStyle(
                color: Color(0xFF00FF00),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0D0D0D),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange.shade700),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange.shade700),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.orange),
                ),
                labelText: 'Ciphertext (Base64)',
                labelStyle: TextStyle(color: Colors.orange.shade400),
                hintText: 'Ingresa el ciphertext...',
                hintStyle: TextStyle(color: Colors.grey.shade600),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _externalIvController,
              style: const TextStyle(
                color: Color(0xFF00FF00),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0D0D0D),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange.shade700),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange.shade700),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.orange),
                ),
                labelText: 'IV (Base64)',
                labelStyle: TextStyle(color: Colors.orange.shade400),
                hintText: 'Ingresa el IV...',
                hintStyle: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _externalKeyController,
              style: const TextStyle(
                color: Color(0xFF00FF00),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0D0D0D),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange.shade700),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange.shade700),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.orange),
                ),
                labelText: 'Encrypted Key RSA (Base64)',
                labelStyle: TextStyle(color: Colors.orange.shade400),
                hintText: 'Ingresa la clave RSA cifrada...',
                hintStyle: TextStyle(color: Colors.grey.shade600),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            _buildButton('Descifrar Externo', _decryptExternal, Colors.amber),

            if (_externalDecryptedResult != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _externalDecryptSuccess == true
                      ? Colors.green.shade900.withValues(alpha: 0.3)
                      : Colors.red.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _externalDecryptSuccess == true
                        ? Colors.green
                        : Colors.red,
                    width: 2,
                  ),
                ),
                child: Text(
                  _externalDecryptedResult!,
                  style: TextStyle(
                    color: _externalDecryptSuccess == true
                        ? Colors.green
                        : Colors.red,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildConsoleOutput(
    String title,
    String content, {
    bool showCopy = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '▸ $title',
                style: TextStyle(
                  color: Colors.green.shade400,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              if (showCopy)
                IconButton(
                  icon: const Icon(Icons.copy, size: 16, color: Colors.grey),
                  onPressed: () => _copyToClipboard(content, title),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: Color(0xFF00FF00),
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleOutputWithCopy(
    String title,
    String content,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '▸ $title',
                  style: TextStyle(
                    color: Colors.green.shade400,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    color: Color(0xFF00FF00),
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
            onPressed: () => _copyToClipboard(content, label),
            tooltip: 'Copiar $label',
          ),
        ],
      ),
    );
  }

  Widget _buildCopyToExternalButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.input, size: 16, color: Colors.amber),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: _copyCurrentToExternalFields,
          icon: const Icon(Icons.input, size: 16, color: Colors.amber),
          label: const Text(
            'Copiar al verificador',
            style: TextStyle(
              color: Colors.amber,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed, Color color) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.2),
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
