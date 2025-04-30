import 'package:flutter/material.dart';
import 'package:flutter_pfe/presentation/navigationbottombar/view/navigationbottombar.dart';
import 'package:flutter_pfe/presentation/ressourses/colormanager.dart';
import 'package:flutter_pfe/presentation/ressourses/valuesmanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_pfe/presentation/project/project.dart';

class Organisation extends StatefulWidget {
  const Organisation({super.key});

  @override
  State<Organisation> createState() => _OrganisationState();
}

class _OrganisationState extends State<Organisation> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveOrganization() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final orgResponse =
          await _supabase
              .from('organisations')
              .insert({
                'name': _nameController.text.trim(),
                'description': _descriptionController.text.trim(),
                'created_at': DateTime.now().toIso8601String(),
                'user_id':
                    _supabase
                        .auth
                        .currentUser!
                        .id, // Link organization with authenticated user
              })
              .select()
              .single();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organization created successfully')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Project()),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${error.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppPadding.p24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create Your Organization',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColor.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppMargine.m20),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Enter organization name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  style: GoogleFonts.poppins(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter organization name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppMargine.m20),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Enter organization description',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  maxLines: 3,
                  style: GoogleFonts.poppins(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter organization description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppMargine.m34),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveOrganization,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : Text(
                              'Create Organization',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
