import 'package:flutter/material.dart';
import 'package:flutter_pfe/presentation/ressourses/colormanager.dart';
import 'package:flutter_pfe/presentation/usersmange/deatil.dart';
import 'package:flutter_pfe/presentation/usersmange/add_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart';

class Users extends StatefulWidget {
  final Map<String, dynamic> selectedProject;
  final Function(Map<String, dynamic>)? onUserUpdated;

  const Users({super.key, required this.selectedProject, this.onUserUpdated});

  @override
  State<Users> createState() => _UsersState();
}

class _UsersState extends State<Users> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  Set<String> _projectMemberIds = {};
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadProjectMembers();
    _searchController.addListener(_filterUsers);
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers =
          _users.where((user) {
            final name =
                '${user['first_name']} ${user['last_name']}'.toLowerCase();
            final email = user['email']?.toString().toLowerCase() ?? '';
            return name.contains(query) || email.contains(query);
          }).toList();
    });
  }

  String _getInitials(String firstName, String lastName) {
    return '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
        .toUpperCase();
  }

  void _setupRealtimeSubscription() {
    _channel = _supabase
        .channel('public:profiles')
        .onPostgresChanges(
          schema: 'public',
          table: 'profiles',
          event: PostgresChangeEvent.all,
          callback: (payload) {
            _loadUsers();
          },
        )
        .subscribe();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() => _isLoading = true);

      final response = await _supabase
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      if (response != null) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response);
          _filteredUsers = _users;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading users: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProjectMembers() async {
    try {
      final response = await _supabase
          .from('project_members')
          .select('user_id')
          .eq('project_id', widget.selectedProject['id']);

      if (response != null) {
        setState(() {
          _projectMemberIds = Set<String>.from(
            response.map((member) => member['user_id'].toString()),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading project members: $e')),
        );
      }
    }
  }

  Future<void> _addUserToProject(String userId) async {
    try {
      await _supabase.from('project_members').insert({
        'project_id': widget.selectedProject['id'],
        'user_id': userId,
        'role': 'worker',
      });

      setState(() {
        _projectMemberIds.add(userId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User added to project successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding user to project: $e')),
        );
      }
    }
  }

  Future<void> _removeUserFromProject(String userId) async {
    try {
      await _supabase
          .from('project_members')
          .delete()
          .eq('project_id', widget.selectedProject['id'])
          .eq('user_id', userId);

      setState(() {
        _projectMemberIds.remove(userId);
        _users.removeWhere((user) => user['id'] == userId);
        _filteredUsers.removeWhere((user) => user['id'] == userId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User removed from project successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing user from project: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.white,
      appBar: AppBar(
        title: const Text('Users'),
        backgroundColor: AppColor.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        final firstName = user['first_name']?.toString() ?? '';
                        final lastName = user['last_name']?.toString() ?? '';
                        final email = user['email']?.toString() ?? '';
                        final userId = user['id']?.toString();
                        final isInProject =
                            userId != null &&
                            _projectMemberIds.contains(userId);

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 3.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppColor.secondprimary,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => UserDetailPage(
                                        user: user,
                                        selectedProject: widget.selectedProject,
                                        onUserUpdated: (updatedUser) {
                                          setState(() {
                                            final index = _users.indexWhere(
                                              (u) =>
                                                  u['id'] == updatedUser['id'],
                                            );
                                            if (index != -1) {
                                              _users[index] = updatedUser;
                                              _filterUsers();
                                            }
                                          });
                                        },
                                      ),
                                ),
                              );
                              if (result == true) {
                                await _loadProjectMembers();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 16.0,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppColor.grey,
                                    child: Text(
                                      _getInitials(firstName, lastName),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$firstName $lastName',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          email,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                user['mission']
                                                            ?.toString()
                                                            .toLowerCase() ==
                                                        'admin'
                                                    ? AppColor.primary
                                                    : AppColor.secondprimary,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            user['mission']?.toString() ??
                                                'No mission',
                                            style: TextStyle(
                                              color:
                                                  user['mission']
                                                              ?.toString()
                                                              .toLowerCase() ==
                                                          'admin'
                                                      ? Colors.white
                                                      : AppColor.primary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        if (isInProject)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 4),
                                            child: Text(
                                              'In Project',
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isInProject ? Icons.remove : Icons.add,
                                      color:
                                          isInProject
                                              ? Colors.red
                                              : AppColor.primary,
                                    ),
                                    onPressed:
                                        userId != null
                                            ? () async {
                                              if (isInProject) {
                                                await _removeUserFromProject(
                                                  userId,
                                                );
                                              } else {
                                                await _addUserToProject(userId);
                                              }
                                              if (widget.onUserUpdated !=
                                                  null) {
                                                widget.onUserUpdated!(user);
                                              }
                                            }
                                            : null,
                                    tooltip:
                                        isInProject
                                            ? 'Remove from project'
                                            : 'Add to project',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddUser(projectId: widget.selectedProject['id'].toString()),
            ),
          );
          
          if (result == true) {
            _loadUsers(); // Reload the list if a new user was added
          }
        },
        backgroundColor: AppColor.primary,
        child: const Icon(Icons.add, color: Colors.white),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
