import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterUserPage extends StatefulWidget {
  const RegisterUserPage({Key? key}) : super(key: key);

  @override
  State<RegisterUserPage> createState() => _RegisterUserPageState();
}

class _RegisterUserPageState extends State<RegisterUserPage> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _missionController = TextEditingController();

  bool _isAdmin = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final mission = _missionController.text.trim();

      // ✅ إنشاء الحساب
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'first_name': firstName, 'last_name': lastName},
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Échec de la création du compte.');
      }

      // ✅ إدخال الملف الشخصي في جدول "profiles"
      final profileData = {
        'id': user.id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'mission': mission,
        'is_admin': _isAdmin,
        'created_at': DateTime.now().toIso8601String(),
      };

      final profileResponse =
          await _supabase
              .from('profiles')
              .insert(profileData)
              .select()
              .single();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الحساب بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = _parseAuthError(e.message);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ أثناء إنشاء الحساب. حاول مرة أخرى.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _parseAuthError(String message) {
    if (message.contains('already registered')) {
      return 'البريد الإلكتروني مستخدم بالفعل.';
    } else if (message.contains('invalid email')) {
      return 'صيغة البريد الإلكتروني غير صحيحة.';
    } else if (message.contains('password')) {
      return 'كلمة المرور ضعيفة (يجب أن تتكون من 6 أحرف على الأقل).';
    }
    return 'خطأ: $message';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل مستخدم جديد')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      if (_errorMessage != null)
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                        ),
                        validator:
                            (value) =>
                                value!.isEmpty
                                    ? 'أدخل البريد الإلكتروني'
                                    : null,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'كلمة المرور',
                        ),
                        obscureText: true,
                        validator:
                            (value) =>
                                value!.length < 6
                                    ? 'كلمة المرور قصيرة جدًا'
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(labelText: 'الاسم'),
                        validator:
                            (value) => value!.isEmpty ? 'أدخل الاسم' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(labelText: 'اللقب'),
                        validator:
                            (value) => value!.isEmpty ? 'أدخل اللقب' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _missionController,
                        decoration: const InputDecoration(labelText: 'المهمة'),
                        validator:
                            (value) => value!.isEmpty ? 'أدخل المهمة' : null,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('هل هو مشرف؟'),
                        value: _isAdmin,
                        onChanged: (value) {
                          setState(() {
                            _isAdmin = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _signUp,
                        child: const Text('تسجيل'),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
