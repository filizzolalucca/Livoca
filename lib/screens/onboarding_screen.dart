import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../theme.dart';
import '../widgets/panda.dart';

/// Primeiro acesso: pede nome e idade. Também usada para editar o perfil.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.editing = false});

  final bool editing;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = AppScope.read(context).profile;
    if (widget.editing && profile != null && _name.text.isEmpty) {
      _name.text = profile.name;
      _age.text = profile.age.toString();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await AppScope.read(context).saveProfile(_name.text, int.parse(_age.text));
    if (!mounted) return;
    if (widget.editing) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.editing ? AppBar(title: const Text('Meu perfil')) : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: Panda(size: 170)),
                    const SizedBox(height: 16),
                    if (!widget.editing) ...[
                      const Text(
                        'Olá! Eu sou o Livoca 🐼',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: LivocaColors.pinkDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vou te ajudar a organizar seus dias, semanas, meses e até o ano todo. '
                        'Como posso te chamar?',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 28),
                    ],
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      maxLength: 40,
                      decoration: const InputDecoration(
                        labelText: 'Seu nome',
                        prefixIcon: Icon(Icons.person_rounded),
                        counterText: '',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Digite seu nome' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _age,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 3,
                      decoration: const InputDecoration(
                        labelText: 'Sua idade',
                        prefixIcon: Icon(Icons.cake_rounded),
                        counterText: '',
                      ),
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null) return 'Digite sua idade';
                        if (n < 1 || n > 120) return 'Digite uma idade válida';
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: Text(widget.editing ? 'Salvar' : 'Começar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
