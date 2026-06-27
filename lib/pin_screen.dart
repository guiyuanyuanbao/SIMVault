import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'models.dart';
import 'l10n.dart';

enum PinMode { setup, confirm, unlock }

class PinScreen extends StatefulWidget {
  final PinMode mode;
  final String? initialPin;
  final SettingsManager? settingsManager;
  final VoidCallback? onUnlocked;

  const PinScreen({
    super.key,
    required this.mode,
    this.initialPin,
    this.settingsManager,
    this.onUnlocked,
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  String _errorMsg = '';
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    if (widget.mode == PinMode.unlock) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (widget.settingsManager?.biometricEnabled != true) return;
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();
      if (canAuthenticate) {
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Please authenticate to access SIMVault',
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );
        if (didAuthenticate && widget.onUnlocked != null) {
          widget.onUnlocked!();
        }
      }
    } catch (e) {
      // Fallback to PIN
    }
  }

  void _onKeyPressed(String key) {
    if (_pin.length < 6) {
      setState(() {
        _pin += key;
        _errorMsg = '';
      });
      if (_pin.length == 6) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) _processPin();
        });
      }
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMsg = '';
      });
    }
  }

  void _processPin() {
    if (widget.mode == PinMode.setup) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PinScreen(
            mode: PinMode.confirm,
            initialPin: _pin,
            settingsManager: widget.settingsManager,
          ),
        ),
      );
    } else if (widget.mode == PinMode.confirm) {
      if (_pin == widget.initialPin) {
        widget.settingsManager?.setAppLock(true, _pin);
        Navigator.pop(context);
      } else {
        setState(() {
          _errorMsg = tr(context, 'pin_not_match');
          _pin = '';
        });
      }
    } else if (widget.mode == PinMode.unlock) {
      if (_pin == widget.settingsManager?.appLockPin) {
        if (widget.onUnlocked != null) {
          widget.onUnlocked!();
        }
      } else {
        setState(() {
          _errorMsg = tr(context, 'incorrect_pin');
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = '';
    if (widget.mode == PinMode.setup) {
      title = tr(context, 'set_pin_6'); // Will add to l10n
    } else if (widget.mode == PinMode.confirm) {
      title = tr(context, 'confirm_pin');
    } else {
      title = tr(context, 'enter_pin');
    }

    return Scaffold(
      appBar: widget.mode != PinMode.unlock ? AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.mode == PinMode.setup) {
              widget.settingsManager?.setAppLock(false, '');
            }
            Navigator.pop(context);
          },
        ),
        title: const Text(''),
      ) : null,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            if (widget.mode == PinMode.unlock)
              Icon(Icons.lock_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
            if (widget.mode == PinMode.unlock)
              const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMsg.isNotEmpty)
              Text(
                _errorMsg,
                style: const TextStyle(color: Colors.redAccent, fontSize: 16),
              )
            else
              const SizedBox(height: 19),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _pin.length
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                );
              }),
            ),
            const Spacer(),
            if (widget.mode == PinMode.unlock && widget.settingsManager?.biometricEnabled == true)
              TextButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint_rounded),
                label: Text(tr(context, 'use_biometrics')),
              )
            else
              const SizedBox(height: 48), // Padding equivalent
            const SizedBox(height: 24),
            _buildNumpad(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildKey('1'),
              const SizedBox(width: 32),
              _buildKey('2'),
              const SizedBox(width: 32),
              _buildKey('3'),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildKey('4'),
              const SizedBox(width: 32),
              _buildKey('5'),
              const SizedBox(width: 32),
              _buildKey('6'),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildKey('7'),
              const SizedBox(width: 32),
              _buildKey('8'),
              const SizedBox(width: 32),
              _buildKey('9'),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 80, height: 80),
              const SizedBox(width: 32),
              _buildKey('0'),
              const SizedBox(width: 32),
              SizedBox(
                width: 80,
                height: 80,
                child: IconButton(
                  icon: const Icon(Icons.backspace_outlined, size: 32),
                  onPressed: _onDelete,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String text) {
    return InkWell(
      onTap: () => _onKeyPressed(text),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
