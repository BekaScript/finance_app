import 'package:flutter/material.dart';
import 'package:personal_finance/services/language_service.dart';
import 'package:personal_finance/services/security_service.dart';

class SetupPinScreen extends StatefulWidget {
  final bool isChangingPin;
  
  const SetupPinScreen({super.key, this.isChangingPin = false});

  @override
  State<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends State<SetupPinScreen> {
  final LanguageService _languageService = LanguageService();
  final SecurityService _securityService = SecurityService();
  
  final List<String> _pin = [];
  final List<String> _confirmPin = [];
  bool _isPinConfirmation = false;
  bool _isCurrentPinVerification = false;
  String _errorText = '';
  
  // For changing PIN
  bool _shouldVerifyCurrentPin = false;
  
  @override
  void initState() {
    super.initState();
    
    // If changing PIN, verify current PIN first
    _shouldVerifyCurrentPin = widget.isChangingPin;
    _isCurrentPinVerification = widget.isChangingPin;
  }
  
  void _addDigit(String digit) {
    if (_isCurrentPinVerification) {
      // First verify current PIN
      if (_pin.length < 4) {
        setState(() {
          _pin.add(digit);
          _errorText = ''; // Clear error text when user is typing
        });
        
        if (_pin.length == 4) {
          _verifyCurrentPin();
        }
      }
    } else if (!_isPinConfirmation) {
      // Entering new PIN
      if (_pin.length < 4) {
        setState(() {
          _pin.add(digit);
          _errorText = ''; // Clear error text when user is typing
        });
        
        if (_pin.length == 4) {
          // Move to confirmation after a short delay
          Future.delayed(const Duration(milliseconds: 300), () {
            setState(() {
              _isPinConfirmation = true;
            });
          });
        }
      }
    } else {
      // Confirming PIN
      if (_confirmPin.length < 4) {
        setState(() {
          _confirmPin.add(digit);
          _errorText = ''; // Clear error text when user is typing
        });
        
        if (_confirmPin.length == 4) {
          _checkPinsMatch();
        }
      }
    }
  }
  
  void _backspace() {
    setState(() {
      if (_isCurrentPinVerification && _pin.isNotEmpty) {
        _pin.removeLast();
      } else if (_isPinConfirmation && _confirmPin.isNotEmpty) {
        _confirmPin.removeLast();
      } else if (!_isPinConfirmation && _pin.isNotEmpty) {
        _pin.removeLast();
      }
    });
  }
  
  Future<void> _verifyCurrentPin() async {
    final currentPin = _pin.join();
    
    final isValid = await _securityService.verifyAppPin(currentPin);
    
    if (isValid) {
      setState(() {
        _isCurrentPinVerification = false;
        _pin.clear();
      });
    } else {
      setState(() {
        _errorText = _languageService.translate('incorrectPin');
        _pin.clear();
      });
    }
  }
  
  Future<void> _checkPinsMatch() async {
    final pin = _pin.join();
    final confirmPin = _confirmPin.join();
    
    if (pin == confirmPin) {
      try {
        await _securityService.setAppPin(pin);
        // Set app lock to true if not changing PIN (first-time setup)
        if (!widget.isChangingPin) {
          await _securityService.setAppLock(true);
        }
        // Go back with success result
        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        print('Error setting PIN: $e');
        setState(() {
          _errorText = _languageService.translate('errorSavingPin');
          _confirmPin.clear();
        });
      }
    } else {
      setState(() {
        _errorText = _languageService.translate('pinsDontMatch');
        _confirmPin.clear();
      });
    }
  }
  
  void _cancel() {
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    String title;
    String subtitle;
    
    if (_isCurrentPinVerification) {
      title = _languageService.translate('enterCurrentPin');
      subtitle = _languageService.translate('enterCurrentPinDescription');
    } else if (!_isPinConfirmation) {
      title = widget.isChangingPin 
          ? _languageService.translate('enterNewPin') 
          : _languageService.translate('createPin');
      subtitle = _languageService.translate('enterPinDescription');
    } else {
      title = _languageService.translate('confirmPin');
      subtitle = _languageService.translate('confirmPinDescription');
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isChangingPin 
              ? _languageService.translate('changePin') 
              : _languageService.translate('setupPin'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF64B5F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.black.withAlpha(179)
              : Colors.white.withAlpha(179),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Title and Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final List<String> currentPin = _isCurrentPinVerification 
                    ? _pin 
                    : (_isPinConfirmation ? _confirmPin : _pin);
                
                final bool isFilled = index < currentPin.length;
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled 
                        ? Colors.deepPurple 
                        : Colors.grey.withOpacity(0.3),
                  ),
                );
              }),
            ),
            
            // Error text
            if (_errorText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  _errorText,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                ),
              ),
            
            const SizedBox(height: 40),
            
            // Number pad
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    // Numbers 1-9
                    if (index < 9) {
                      final number = (index + 1).toString();
                      return _buildNumberButton(number);
                    } 
                    // Cancel button
                    else if (index == 9) {
                      return _buildActionButton(
                        Icons.close,
                        _cancel,
                        color: Colors.red,
                      );
                    } 
                    // 0 button
                    else if (index == 10) {
                      return _buildNumberButton('0');
                    } 
                    // Backspace button
                    else {
                      return _buildActionButton(
                        Icons.backspace,
                        _backspace,
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNumberButton(String number) {
    return InkWell(
      onTap: () => _addDigit(number),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[200],
        ),
        alignment: Alignment.center,
        child: Text(
          number,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  Widget _buildActionButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[200],
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: color,
          size: 24,
        ),
      ),
    );
  }
} 