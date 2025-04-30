import 'package:flutter/material.dart';
import 'package:flutter_pfe/presentation/ressourses/colormanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserDetailPage extends StatefulWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic> selectedProject;
  final Function(Map<String, dynamic>)? onUserUpdated;

  const UserDetailPage({
    super.key,
    required this.user,
    required this.selectedProject,
    this.onUserUpdated,
  });

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _missionController;
  late TextEditingController _emailController;
  bool _isAdmin = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInProject = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.user['first_name'],
    );
    _lastNameController = TextEditingController(text: widget.user['last_name']);
    _missionController = TextEditingController(text: widget.user['mission']);
    _emailController = TextEditingController();
    _isAdmin = widget.user['is_admin'] ?? false;

    _loadUserEmail();
    _loadProjectMembership();
  }

  Future<void> _loadUserEmail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response =
          await _supabase
              .from('auth.users')
              .select('email')
              .eq('id', widget.user['id'])
              .single();

      if (response != null && response['email'] != null) {
        _emailController.text = response['email'];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading user email: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProjectMembership() async {
    try {
      final response =
          await _supabase
              .from('project_members')
              .select()
              .eq('user_id', widget.user['id'])
              .eq('project_id', widget.selectedProject['id'])
              .maybeSingle();

      setState(() {
        _isInProject = response != null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading project membership: $e')),
        );
      }
    }
  }

  Future<void> _toggleProjectMembership() async {
    try {
      setState(() {
        _isLoading = true;
      });

      if (_isInProject) {
        await _supabase
            .from('project_members')
            .delete()
            .eq('user_id', widget.user['id'])
            .eq('project_id', widget.selectedProject['id']);
      } else {
        await _supabase.from('project_members').insert({
          'user_id': widget.user['id'],
          'project_id': widget.selectedProject['id'],
          'role': 'worker',
        });
      }

      setState(() {
        _isInProject = !_isInProject;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isInProject
                  ? 'User added to project successfully'
                  : 'User removed from project successfully',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating project membership: $e')),
        );
      }
    }
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedUser = {
        'id': widget.user['id'],
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'mission': _missionController.text,
        'is_admin': _isAdmin,
      };

      await _supabase
          .from('profiles')
          .update(updatedUser)
          .eq('id', widget.user['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User updated successfully')),
        );
        if (widget.onUserUpdated != null) {
          widget.onUserUpdated!(updatedUser);
        }
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating user: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteUser() async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete User'),
            content: const Text('Are you sure you want to delete this user?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() {
                    _isLoading = true;
                  });

                  try {
                    // First delete from profiles table
                    await _supabase
                        .from('profiles')
                        .delete()
                        .eq('id', widget.user['id']);

                    // Then delete from auth.users table using a database function
                    await _supabase.rpc(
                      'delete_auth_user',
                      params: {'user_id': widget.user['id']},
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('User deleted successfully'),
                        ),
                      );
                      Navigator.pop(context, true);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error deleting user: $e')),
                      );
                    }
                  } finally {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.white,
      appBar: AppBar(
        title: const Text('User Details'),
        backgroundColor: AppColor.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _updateUser,
            tooltip: 'Save Changes',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColor.primary,
                          child: Text(
                            '${_firstNameController.text.isNotEmpty ? _firstNameController.text[0] : ''}${_lastNameController.text.isNotEmpty ? _lastNameController.text[0] : ''}'
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 30,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator:
                            (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator:
                            (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        readOnly: true,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _missionController,
                        decoration: InputDecoration(
                          labelText: 'Mission',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Admin'),
                        value: _isAdmin,
                        onChanged: (value) => setState(() => _isAdmin = value),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('Project Membership'),
                        subtitle: Text(
                          'Project: ${widget.selectedProject['name'] ?? 'Unknown'}',
                        ),
                        trailing: Switch(
                          value: _isInProject,
                          onChanged: (value) => _toggleProjectMembership(),
                          activeColor: AppColor.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _updateUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColor.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Update User',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _deleteUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: AppColor.primary),
                            ),
                          ),
                          child: Text(
                            'Delete User',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColor.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
