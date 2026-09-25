import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/practice_session_screen.dart';
import 'screens/mock_test_screen.dart';
import 'models/mock_models.dart';
import 'models/dashboard_models.dart';
import 'services/practice_service.dart';
import 'services/mock_service.dart';
import 'services/dashboard_service.dart';
import 'services/notification_service.dart';
import 'screens/notifications_screen.dart';

const blue = Color(0xff0058be);
const blueContainer = Color(0xff2170e4);
const navy = Color(0xff1f2b3d);
const green = Color(0xff00855b);
const greenSoft = Color(0xffd6f8e6);
const canvas = Color(0xfff7f9fb);
const ink = Color(0xff191c1e);
const muted = Color(0xff596273);
const line = Color(0xffe0e3e5);

void main() => runApp(const PlacementApp());

class Task {
  Task(this.title, this.category, this.xp, {this.id = '', this.completed = false});
  factory Task.fromJson(Map<String, dynamic> json) => Task(
    json['title'] as String? ?? '',
    json['category'] as String? ?? 'General',
    (json['xp'] as num?)?.toInt() ?? 15,
    id: json['id'] as String? ?? '',
    completed: json['completed'] as bool? ?? false,
  );
  final String id;
  final String title;
  final String category;
  final int xp;
  bool completed;
}

class AppState extends ChangeNotifier {
  AppState({PlacementApi? api}) : api = api ?? PlacementApi();
  final PlacementApi api;
  bool initializing = true;
  int tab = 0;
  bool signedIn = false;
  int xp = 148;
  String profileName = 'Rahul Sharma';
  String profileRollNumber = '21CS084';
  String profileCgpa = '8.74';
  String profileDegree = 'B.Tech CSE';
  String profileCollege = '';
  String profileCourse = 'B.Tech CSE';
  int? profileGraduationYear;
  String profileTargetRole = '';
  String profileSkillLevel = 'Beginner';
  bool notificationsEnabled = true;
  String taskFilter = 'All Tasks';
  final tasks = <Task>[
    Task(
      'Solve 10 Profit & Loss Aptitude questions',
      'Aptitude',
      15,
      completed: true,
    ),
    Task('Practice 2 Hard Tree Traversal coding problems', 'Coding & DSA', 25),
    Task('Revise Operating System Deadlocks & Semaphores', 'Tech Core', 20),
    Task(
      'Record 2-min self-introduction video for HR round',
      'Soft Skills',
      10,
    ),
  ];

  int get completedTasks => tasks.where((task) => task.completed).length;

  Future<void> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    api.token = preferences.getString('placement_auth_token');
    if (api.token != null) {
      try {
        final user = await api.currentUser();
        _applyUser(user);
        tasks
          ..clear()
          ..addAll((await api.tasks()).map(Task.fromJson));
        signedIn = true;
      } catch (_) {
        await preferences.remove('placement_auth_token');
        api.token = null;
      }
    }
    initializing = false;
    notifyListeners();
  }
  void setTab(int value) {
    tab = value;
    notifyListeners();
  }

  void setTaskFilter(String value) {
    taskFilter = value;
    notifyListeners();
  }

  Future<String?> login({
    required String email,
    required String password,
    String name = '',
    bool createAccount = false,
    String college = '',
    String course = '',
    int? graduationYear,
    String targetRole = '',
    String skillLevel = 'Beginner',
  }) async {
    try {
      final result = await (createAccount
          ? api.signup(
              name: name,
              email: email,
              password: password,
              college: college,
              course: course,
              graduationYear: graduationYear,
              targetRole: targetRole,
              skillLevel: skillLevel,
            )
          : api.login(email: email, password: password));
      _applyUser(result['user'] as Map<String, dynamic>);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('placement_auth_token', api.token!);
      final remoteTasks = await api.tasks();
      tasks
        ..clear()
        ..addAll(remoteTasks.map(Task.fromJson));
      signedIn = true;
      notifyListeners();
      return null;
    } on PlacementApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Unable to connect to the placement backend';
    }
  }

  void _applyUser(Map<String, dynamic> user) {
    api.token = user['_token'] as String? ?? api.token;
    profileName = user['name'] as String? ?? profileName;
    profileRollNumber = user['rollNumber'] as String? ?? profileRollNumber;
    profileCgpa = user['cgpa'] as String? ?? profileCgpa;
    profileDegree = user['degree'] as String? ?? profileDegree;
    profileCollege = user['college'] as String? ?? profileCollege;
    profileCourse = user['course'] as String? ?? profileCourse;
    profileGraduationYear = (user['graduationYear'] as num?)?.toInt();
    profileTargetRole = user['targetRole'] as String? ?? profileTargetRole;
    profileSkillLevel = user['skillLevel'] as String? ?? profileSkillLevel;
    notificationsEnabled = user['notificationsEnabled'] as bool? ?? true;
    xp = (user['xp'] as num?)?.toInt() ?? 0;
  }

  void logout() {
    api.token = null;
    SharedPreferences.getInstance().then(
      (preferences) => preferences.remove('placement_auth_token'),
    );
    signedIn = false;
    tab = 0;
    notifyListeners();
  }

  Future<void> toggleTask(Task task) async {
    task.completed = !task.completed;
    xp += task.completed ? task.xp : -task.xp;
    notifyListeners();
    if (task.id.isNotEmpty) {
      try {
        await api.updateTask(task.id, task.completed);
      } catch (_) {
        task.completed = !task.completed;
        xp += task.completed ? task.xp : -task.xp;
        notifyListeners();
      }
    }
  }

  Future<void> addTask(String title, String category) async {
    final taskTitle = title.trim().isEmpty
        ? 'Complete LeetCode Daily Challenge'
        : title.trim();
    try {
      final task = await api.addTask(taskTitle, category);
      tasks.add(Task.fromJson(task));
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> deleteTask(Task task) async {
    if (task.id.isEmpty) return false;
    try {
      await api.deleteTask(task.id);
      tasks.remove(task);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void updateProfile({
    required String name,
    required String rollNumber,
    required String cgpa,
    required String degree,
    String? college,
    String? course,
    int? graduationYear,
    String? targetRole,
    String? skillLevel,
  }) {
    profileName = name.trim().isEmpty ? profileName : name.trim();
    profileRollNumber = rollNumber.trim().isEmpty
        ? profileRollNumber
        : rollNumber.trim();
    profileCgpa = cgpa.trim().isEmpty ? profileCgpa : cgpa.trim();
    profileDegree = degree.trim().isEmpty ? profileDegree : degree.trim();
    if (college != null && college.trim().isNotEmpty) profileCollege = college.trim();
    if (course != null && course.trim().isNotEmpty) profileCourse = course.trim();
    if (graduationYear != null) profileGraduationYear = graduationYear;
    if (targetRole != null) profileTargetRole = targetRole.trim();
    if (skillLevel != null) profileSkillLevel = skillLevel;
    api.updateProfile({
      'name': profileName,
      'rollNumber': profileRollNumber,
      'cgpa': profileCgpa,
      'degree': profileDegree,
      'college': profileCollege,
      'course': profileCourse,
      'graduationYear': profileGraduationYear,
      'targetRole': profileTargetRole,
      'skillLevel': profileSkillLevel,
    });
    notifyListeners();
  }

  void setNotificationsEnabled(bool value) {
    notificationsEnabled = value;
    api.updateProfile({'notificationsEnabled': value});
    notifyListeners();
  }
}

class PlacementApiException implements Exception {
  PlacementApiException(this.message);
  final String message;
}

class PlacementApi {
  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    return kIsWeb ? 'http://localhost:3000/api' : 'http://10.0.2.2:3000/api';
  }
  String? token;
  String? get authToken => token;

  Future<Map<String, dynamic>> _request(String method, String path, [Map<String, dynamic>? body]) async {
    final headers = {'content-type': 'application/json', if (token != null) 'authorization': 'Bearer $token'};
    final uri = Uri.parse('$baseUrl$path');
    final response = method == 'GET'
        ? await http.get(uri, headers: headers)
      : method == 'DELETE'
        ? await http.delete(uri, headers: headers)
        : method == 'PATCH'
            ? await http.patch(uri, headers: headers, body: jsonEncode(body ?? {}))
            : await http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PlacementApiException(decoded['error'] as String? ?? 'Backend request failed');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    }) async {
      final result = await _request(
      'POST',
      '/v1/auth/login',
      {
        'email': email,
        'password': password,
      },
    );

    token = result['token'] as String?;

    return {
      ...result,
      'user': {
        ...result['user'] as Map<String, dynamic>,
        '_token': token,
      },
    };
  }

  Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
    String college = '',
    String course = '',
    int? graduationYear,
    String targetRole = '',
    String skillLevel = 'Beginner',
  }) async {
    final result = await _request(
      'POST',
      '/v1/auth/signup',
      {
        'name': name,
        'email': email,
        'password': password,
        'college': college,
        'course': course,
        'graduationYear': graduationYear,
        'targetRole': targetRole,
        'skillLevel': skillLevel,
      },
    );

    token = result['token'] as String?;

    return {
      ...result,
      'user': {
        ...result['user'] as Map<String, dynamic>,
        '_token': token,
      },
    };
  }
  Future<Map<String, dynamic>> currentUser() async => (await _request('GET', '/me'))['user'] as Map<String, dynamic>;
  Future<Map<String, dynamic>> dashboard() async => await _request('GET', '/dashboard?timezoneOffset=${DateTime.now().timeZoneOffset.inMinutes}');
  Future<List<Map<String, dynamic>>> tasks() async => ((await _request('GET', '/tasks'))['tasks'] as List).cast<Map<String, dynamic>>();
  Future<Map<String, dynamic>> addTask(String title, String category) async => (await _request('POST', '/tasks', {'title': title, 'category': category}))['task'] as Map<String, dynamic>;
  Future<void> updateTask(String id, bool completed) async { await _request('PATCH', '/tasks/$id', {'completed': completed}); }
  Future<void> deleteTask(String id) async { await _request('DELETE', '/tasks/$id'); }
  Future<void> updateProfile(Map<String, dynamic> values) async { await _request('PATCH', '/me', values); }
}

class PlacementApp extends StatefulWidget {
  const PlacementApp({super.key});
  @override
  State<PlacementApp> createState() => _PlacementAppState();
}

class _PlacementAppState extends State<PlacementApp> {
  final state = AppState();

  @override
  void initState() {
    super.initState();
    state.restoreSession();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (_, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: canvas,
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
        fontFamily: 'Arial',
      ),
        home: state.initializing
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : state.signedIn
          ? AppShell(state: state)
          : AuthFlow(state: state),
    ),
  );
}

class AuthFlow extends StatefulWidget {
  const AuthFlow({required this.state, super.key});
  final AppState state;
  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  bool splash = true;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer(
      const Duration(milliseconds: 2400),
      () => setState(() => splash = false),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => splash
      ? SplashScreen(onContinue: () => setState(() => splash = false))
      : LoginScreen(state: widget.state);
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.onContinue, super.key});
  final VoidCallback onContinue;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: StatusBadge(text: 'DRIVE 2025 READY'),
            ),
            const Spacer(),
            Image.asset(
              'assets/placement_tracker_logo.png',
              width: 112,
              height: 112,
            ),
            const SizedBox(height: 22),
            const Text(
              'Placement Preparation Tracker',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Track. Prepare. Get Placed.',
              style: TextStyle(
                fontSize: 16,
                color: muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Over 2,400+ Offers Tracked',
              style: TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 28),
            AnimatedBuilder(
              animation: controller,
              builder: (_, _) => Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Syncing company hiring patterns & core rounds',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      Text(
                        '${(64 + controller.value * 36).round()}%',
                        style: const TextStyle(
                          color: blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: .64 + controller.value * .36,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(10),
                    color: blue,
                    backgroundColor: line,
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Text(
              'Automatically redirecting to login...',
              style: TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: widget.onContinue,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Get Started'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.state, super.key});
  final AppState state;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  bool signup = false, obscure = true;
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirmPassword = TextEditingController(),
      college = TextEditingController(),
      course = TextEditingController();
    String targetRole = 'Software Developer', skillLevel = 'Beginner';
    int graduationYear = 2027;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    college.dispose();
    course.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final error = await widget.state.login(
      email: email.text,
      password: password.text,
      name: name.text,
      createAccount: signup,
      college: college.text,
      course: course.text,
      graduationYear: graduationYear,
      targetRole: targetRole,
      skillLevel: skillLevel,
    );
    if (mounted && error != null) snack(context, error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: form,
                child: Column(
                  children: [
                    Image.asset(
                      'assets/placement_tracker_logo.png',
                      width: 80,
                      height: 80,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Placement Prep Tracker',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sign in to continue your campus prep journey',
                      style: TextStyle(color: muted),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  label: Text('Student Login'),
                                  icon: Icon(Icons.school),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text('Create Account'),
                                  icon: Icon(Icons.person_add),
                                ),
                              ],
                              selected: {signup},
                              onSelectionChanged: (value) =>
                                  setState(() => signup = value.first),
                            ),
                            const SizedBox(height: 18),
                            if (signup) ...[
                              Field(
                                controller: name,
                                label: 'Full Name',
                                icon: Icons.badge,
                                validator: required,
                              ),
                              const SizedBox(height: 12),
                            ],
                            Field(
                              controller: email,
                              label: signup
                                  ? 'College / Institutional Email'
                                  : 'Email or College Roll No.',
                              icon: Icons.mail,
                              validator: required,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: password,
                              obscureText: obscure,
                                validator: (value) => signup &&
                                        (value == null ||
                                            value.length < 8 ||
                                            !RegExp(r'[A-Za-z]').hasMatch(value) ||
                                            !RegExp(r'\d').hasMatch(value))
                                    ? 'Use 8+ characters with a letter and number'
                                    : value == null || value.isEmpty
                                    ? 'Password is required'
                                    : null,
                              decoration:
                                  inputDecoration(
                                    'Password',
                                    Icons.lock,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      onPressed: () =>
                                          setState(() => obscure = !obscure),
                                      icon: Icon(
                                        obscure
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                      ),
                                    ),
                                  ),
                            ),
                            if (signup) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: confirmPassword,
                                obscureText: obscure,
                                validator: (value) => value != password.text
                                    ? 'Passwords do not match'
                                    : null,
                                decoration: inputDecoration(
                                  'Confirm Password',
                                  Icons.lock_outline,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Field(
                                controller: college,
                                label: 'College',
                                icon: Icons.account_balance,
                                validator: required,
                              ),
                              const SizedBox(height: 12),
                              Field(
                                controller: course,
                                label: 'Course / Degree',
                                icon: Icons.school,
                                validator: required,
                              ),
                            ],
                            if (!signup)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => snack(
                                    context,
                                    'Password reset instructions requested',
                                  ),
                                  child: const Text('Forgot Password?'),
                                ),
                              ),
                            if (signup) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: graduationYear.toString(),
                                decoration: inputDecoration(
                                  'Batch / Graduation Year',
                                  Icons.calendar_today,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: '2025',
                                    child: Text('Class of 2025 (Final Year)'),
                                  ),
                                  DropdownMenuItem(
                                    value: '2026',
                                    child: Text(
                                      'Class of 2026 (Pre-Final Year)',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: '2027',
                                    child: Text('Class of 2027 (Sophomore)'),
                                  ),
                                ],
                                onChanged: (value) => setState(
                                  () => graduationYear = int.parse(value!),
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: targetRole,
                                decoration: inputDecoration('Target Role', Icons.work_outline),
                                items: const ['Software Developer', 'AI/ML Engineer', 'Data Scientist', 'Web Developer', 'Other']
                                    .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                                    .toList(),
                                onChanged: (value) => setState(() => targetRole = value ?? targetRole),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: skillLevel,
                                decoration: inputDecoration('Current Skill Level', Icons.trending_up),
                                items: const ['Beginner', 'Intermediate', 'Advanced']
                                    .map((level) => DropdownMenuItem(value: level, child: Text(level)))
                                    .toList(),
                                onChanged: (value) => setState(() => skillLevel = value ?? skillLevel),
                              ),
                            ],
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: submit,
                                icon: const Icon(Icons.arrow_forward),
                                label: Text(
                                  signup
                                      ? 'Start Prep Journey'
                                      : 'Login to Dashboard',
                                ),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: () => snack(
                                context,
                                'Google SSO needs a configured identity provider',
                              ),
                              icon: const Icon(Icons.g_mobiledata),
                              label: const Text('Google Student SSO'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() => signup = !signup),
                      child: Text(
                        signup
                            ? 'Already have an account? Sign In'
                            : "Don't have an account? Create Account",
                      ),
                    ),
                    const SizedBox(height: 16),
                    const InfoBanner(
                      text:
                          'Campus Proven • Over 45,000+ Students Placed in Top Tier-1 Tech & Core Companies',
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

class AppShell extends StatefulWidget {
  const AppShell({required this.state, super.key});
  final AppState state;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final pages = [
      HomeScreen(state: widget.state),
      const PreparationScreen(),
      PracticeScreen(api: widget.state.api),
      MocksScreen(api: widget.state.api),
      const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: widget.state.tab, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.state.tab,
        onDestinationSelected: widget.state.setTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: 'Prep',
          ),
          NavigationDestination(
            icon: Icon(Icons.code_outlined),
            selectedIcon: Icon(Icons.code),
            label: 'Practice',
          ),
          NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz),
            label: 'Mocks',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.state, super.key});
  final AppState state;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<DashboardData> dashboardFuture = DashboardService(widget.state.api).load();

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted && widget.state.signedIn) reload();
  }

  void reload() => setState(() => dashboardFuture = DashboardService(widget.state.api).load());

  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Home / Dashboard',
    child: FutureBuilder<DashboardData>(
      future: dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Unable to load your progress.', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 12), FilledButton.icon(onPressed: reload, icon: const Icon(Icons.refresh), label: const Text('Retry'))])));
        }
        final data = snapshot.data!;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('Hello, ${data.userName}!', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          if (data.targetRole.isNotEmpty) Text('Target role: ${data.targetRole}', style: const TextStyle(color: muted)),
          const SizedBox(height: 18),
          GradientCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const StatusBadge(text: 'YOUR PROGRESS'), Text('${data.progress.overallProgress}% complete', style: const TextStyle(color: Colors.white))]),
            const SizedBox(height: 18),
            Text(data.progress.hasActivity ? 'Preparation in motion' : 'You are just getting started', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(data.progress.hasActivity ? 'Keep building consistent preparation activity.' : 'Complete a task or start practice to build your progress.', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16), ProgressBar(value: data.progress.overallProgress / 100, color: greenSoft),
            const SizedBox(height: 12), Text('${data.progress.currentStreak} day streak', style: const TextStyle(color: Colors.white70)),
          ])),
          const SizedBox(height: 22),
          const SectionTitle(title: "Today's Progress", subtitle: 'Calculated from your saved activity'),
          GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.35, children: [
            MetricCard(title: 'Tasks', value: '${data.progress.tasksCompleted}', detail: '${data.progress.tasksPending} pending', icon: Icons.checklist),
            MetricCard(title: 'Practice', value: '${data.progress.practiceAccuracy}%', detail: '${data.progress.practiceQuestionsAttempted} questions', icon: Icons.terminal, color: green),
            MetricCard(title: 'Mock Tests', value: '${data.progress.averageMockScore}%', detail: '${data.progress.mockTestsCompleted} completed', icon: Icons.assignment_turned_in, color: navy),
            MetricCard(title: 'Streak', value: '${data.progress.currentStreak}', detail: 'active days', icon: Icons.local_fire_department),
          ]),
          const SizedBox(height: 18),
          if (!data.progress.hasActivity) InfoBanner(text: 'No performance data yet. Start a practice session, complete a task, or take a mock test.'),
          if (data.strengths.isNotEmpty) ...[const SectionTitle(title: 'Strong Areas'), Text(data.strengths.join(' • '), style: const TextStyle(color: green, fontWeight: FontWeight.bold))],
          if (data.weakAreas.isNotEmpty) ...[const SizedBox(height: 16), const SectionTitle(title: 'Needs Attention'), Text(data.weakAreas.join(' • '), style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold))],
          if (data.recommendations.isNotEmpty) ...[const SizedBox(height: 18), const SectionTitle(title: 'Recommended For You'), ...data.recommendations.take(3).map((item) => Card(child: ListTile(leading: const Icon(Icons.arrow_forward, color: blue), title: Text(item.title), subtitle: Text(item.description))))],
          const SizedBox(height: 18),
          TaskSummary(state: widget.state),
        ]);
      },
    ),
  );
}

class TaskSummary extends StatelessWidget {
  const TaskSummary({required this.state, super.key});
  final AppState state;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionTitle(title: "Today's Daily Target"),
              Text(
                '${state.completedTasks} of ${state.tasks.length} Done',
                style: const TextStyle(color: muted),
              ),
            ],
          ),
          ...state.tasks
              .take(3)
              .map((task) => TaskRow(task: task, state: state)),
        ],
      ),
    ),
  );
}

class PreparationScreen extends StatelessWidget {
  const PreparationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorWidgetOfExactType<AppShell>()!.state;
    return AppPage(
      title: 'Preparation Tracker',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InfoBanner(
            text:
                '⚡ ACTIVE SPRINT\nStudy & Preparation Tracker\n12-Day Streak • 3 days to Bronze Shield',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Weekly Goal',
                  value: '80%',
                  detail: '24 / 30 Hours logged',
                  icon: Icons.timelapse,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricCard(
                  title: "Today's Log",
                  value: '3.5',
                  detail: 'hrs today',
                  icon: Icons.trending_up,
                  color: green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SectionTitle(
            title: 'Category Mastery',
            subtitle: '5 Tracked Tracks',
          ),
          ...const [
            MetricCard(
              title: 'Aptitude',
              value: '78%',
              detail: '142/180 topics',
              icon: Icons.calculate,
            ),
            MetricCard(
              title: 'Coding & DSA',
              value: '68%',
              detail: '110/160 questions',
              icon: Icons.terminal,
              color: navy,
            ),
            MetricCard(
              title: 'Technical Subjects',
              value: '55%',
              detail: '22/40 topics',
              icon: Icons.developer_board,
            ),
            MetricCard(
              title: 'Communication & Soft Skills',
              value: '85%',
              detail: 'Ready',
              icon: Icons.record_voice_over,
              color: green,
            ),
            MetricCard(
              title: 'Interview Preparation',
              value: '60%',
              detail: 'In Progress',
              icon: Icons.architecture,
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionTitle(title: 'Actionable Tasks'),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${state.completedTasks} completed • ${state.xp} XP',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  FilledButton.icon(
                    onPressed: () => showAddTask(context, state),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Task'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: ['All Tasks', 'Pending', 'Completed']
                .map(
                  (filter) => ChoiceChip(
                    label: Text(filter),
                    selected: state.taskFilter == filter,
                    onSelected: (_) => state.setTaskFilter(filter),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          ...state.tasks
              .where(
                (task) =>
                    state.taskFilter == 'All Tasks' ||
                    (state.taskFilter == 'Completed'
                        ? task.completed
                        : !task.completed),
              )
              .map((task) => TaskRow(task: task, state: state, detailed: true)),
        ],
      ),
    );
  }
}

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({required this.api, super.key});
  final PlacementApi api;
  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  int tab = 0;
  String difficulty = 'Medium', duration = '20 Qs';
  final focusTopics = <String>{'Quantitative'};
  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Practice (Aptitude & Coding)',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InfoBanner(
          text:
              '⚡ DAILY MOMENTUM BOOST\nPractice Arena\nRecent 5 Drills Accuracy 84% • Avg Pace 52s/question',
        ),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Aptitude')),
            ButtonSegment(value: 1, label: Text('Coding & DSA')),
            ButtonSegment(value: 2, label: Text('Technical MCQs')),
          ],
          selected: {tab},
          onSelectionChanged: (v) => setState(() => tab = v.first),
        ),
        const SizedBox(height: 16),
        const Text(
          'Focus Topic',
          style: TextStyle(fontWeight: FontWeight.bold, color: muted),
        ),
        Wrap(
          spacing: 8,
          children:
              [
                    'Quantitative',
                    'Logical Reasoning',
                    'Data Structures',
                    'SQL & Databases',
                  ]
                  .map(
                    (topic) => FilterChip(
                      label: Text(topic),
                      selected: focusTopics.contains(topic),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          focusTopics.add(topic);
                        } else {
                          focusTopics.remove(topic);
                        }
                      }),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 16),
        const Text(
          'Difficulty Level',
          style: TextStyle(fontWeight: FontWeight.bold, color: muted),
        ),
        Wrap(
          spacing: 8,
          children: ['Easy', 'Medium', 'Hard']
              .map(
                (x) => ChoiceChip(
                  label: Text(x),
                  selected: difficulty == x,
                  onSelected: (_) => setState(() => difficulty = x),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        const Text(
          'Sprint Duration',
          style: TextStyle(fontWeight: FontWeight.bold, color: muted),
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: '10 Qs', label: Text('10 Qs\n15m')),
            ButtonSegment(value: '20 Qs', label: Text('20 Qs\n30m')),
            ButtonSegment(value: '30 Qs', label: Text('30 Qs\n45m')),
          ],
          selected: {duration},
          onSelectionChanged: (v) => setState(() => duration = v.first),
        ),
        const SizedBox(height: 22),
        const SectionTitle(
          title: 'Curated Drills',
          subtitle: 'Recommended for your target recruitment drives',
        ),
        PracticeCard(
          title: 'Speed Math & Number Systems Drill',
          detail: '20 Qs • 45s/Q pace • 85% (17/20)',
          resume: false,
        ),
        PracticeCard(
          title: 'Binary Trees & BST Masterclass',
          detail: '5 Coding Problems • 3/5 Solved',
          resume: true,
        ),
        PracticeCard(
          title: 'SQL Querying & Joins Challenge',
          detail: '15 MCQs & Queries • Prev Score: 92%',
          resume: false,
        ),
        if (widget.api.authToken != null) ...[
          const SizedBox(height: 16),
          const SectionTitle(title: 'Practice History'),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: PracticeService(
              baseUrl: PlacementApi.baseUrl,
              token: widget.api.authToken!,
            ).history(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return const InfoBanner(text: 'Practice history is temporarily unavailable.');
              }
              final attempts = snapshot.data ?? const [];
              if (attempts.isEmpty) {
                return const InfoBanner(text: 'No practice attempts yet. Start a drill to build your history.');
              }
              return Column(
                children: attempts.take(3).map((attempt) {
                  final score = (attempt['score'] as num?)?.toInt() ?? 0;
                  final total = (attempt['total'] as num?)?.toInt() ?? 0;
                  final accuracy = total == 0 ? 0 : (score / total * 100).round();
                  return Card(
                    child: ListTile(
                      title: Text(attempt['topic'] as String? ?? 'Practice'),
                      subtitle: Text('$score/$total score'),
                      trailing: Text('$accuracy%'),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {
            final token = widget.api.authToken;
            if (token == null) {
              snack(context, 'Sign in to start practice');
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PracticeSessionScreen(
                  service: PracticeService(
                    baseUrl: PlacementApi.baseUrl,
                    token: token,
                  ),
                  category: tab == 0 ? 'Aptitude' : tab == 1 ? 'DSA' : 'DBMS',
                  difficulty: difficulty,
                ),
              ),
            );
          },
          icon: const Icon(Icons.bolt),
          label: const Text('Quick 10-Question Blitz'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        ),
      ],
    ),
  );
}

class MocksScreen extends StatelessWidget {
  const MocksScreen({required this.api, super.key});
  final PlacementApi api;
  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Mock Tests & Interviews',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const StatusBadge(text: 'EXAM READINESS: 84% • AI COACH ONLINE'),
        const SizedBox(height: 14),
        GradientCard(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Performance Diagnostics',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Strong In: Quantitative Aptitude & Object Oriented Programming',
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 6),
              Text(
                'Focus Area: Graph Algorithms & Advanced Vocabulary',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle(
          title: 'Active Simulation Tracks',
          subtitle: '4 Available',
        ),
        if (api.authToken != null)
          FutureBuilder<List<MockTest>>(
            future: MockService(
              baseUrl: PlacementApi.baseUrl,
              token: api.authToken!,
            ).tests(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return InfoBanner(text: 'Unable to load live mock tests: ${snapshot.error}');
              }
              return Column(
                children: snapshot.data!
                    .map(
                      (test) => MockCard(
                        title: test.title,
                        detail: '${test.category} • ${test.durationMinutes} mins • ${test.questionCount} questions',
                        action: 'Start Test',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MockTestScreen(
                              service: MockService(
                                baseUrl: PlacementApi.baseUrl,
                                token: api.authToken!,
                              ),
                              testId: test.id,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        MockCard(
          title: 'Full-Length Campus Mock Test',
          detail:
              'TCS / Accenture / Cognizant Pattern • 60 Mins • 50 Questions',
          action: 'Start Test',
        ),
        MockCard(
          title: 'Product Company Coding Assessment',
          detail:
              'Amazon / Uber Style Challenge • 90 Mins • 3 Algorithmic Problems',
          action: 'Start Test',
        ),
        MockCard(
          title: '1-on-1 AI Technical Interview',
          detail: 'DSA & System Design Breakdown • 30 Mins • Audio Simulation',
          action: 'Begin Interview',
        ),
        MockCard(
          title: 'HR Behavioral & Cultural Fit Simulation',
          detail:
              'Common HR questions • STAR Format • Confidence Score Tracker',
          action: 'Practice HR',
        ),
        const SizedBox(height: 16),
        const SectionTitle(title: 'Recent Mock History'),
        if (api.authToken != null)
          FutureBuilder<List<Map<String, dynamic>>>(
            future: MockService(
              baseUrl: PlacementApi.baseUrl,
              token: api.authToken!,
            ).history(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
              if (snapshot.hasError) return const InfoBanner(text: 'Mock history is temporarily unavailable.');
              final attempts = snapshot.data ?? const [];
              if (attempts.isEmpty) return const InfoBanner(text: 'No mock attempts yet. Start a mock test to see results here.');
              return Column(children: attempts.take(3).map((attempt) => HistoryCard(title: attempt['title'] as String? ?? 'Mock Test', score: '${attempt['score']}/${attempt['total']}', percentile: 'Saved result')).toList());
            },
          ),
        HistoryCard(
          title: 'Tier-1 Technical Assessment #4',
          score: '86/100',
          percentile: '94th %ile',
        ),
        HistoryCard(
          title: 'Speed Quant Mock #7',
          score: '72/100',
          percentile: '71st %ile',
        ),
        const InfoBanner(
          text:
              'Weekly Mock Challenge\nComplete 2 more simulations to unlock the Google mock question bank.',
        ),
      ],
    ),
  );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorWidgetOfExactType<AppShell>()!.state;
    return AppPage(
      title: 'Progress & Profile',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                radius: 30,
                backgroundImage: AssetImage('assets/student_avatar.png'),
              ),
              title: Text(
                state.profileName,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${state.profileRollNumber} • Final Year\nCGPA ${state.profileCgpa} / 10.0 • ${state.profileDegree}',
              ),
              trailing: IconButton(
                onPressed: () => showEditProfile(context, state),
                icon: const Icon(Icons.edit),
              ),
            ),
          ),
          const SizedBox(height: 14),
          GradientCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Placement Readiness',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Top 15% in Batch',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                CircularProgressIndicator(
                  value: .78,
                  color: greenSoft,
                  backgroundColor: Colors.white30,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              MetricCard(
                title: 'Tasks Completed',
                value: '${148 + state.completedTasks - 1}',
                detail: 'Live sync',
                icon: Icons.checklist,
              ),
              const MetricCard(
                title: 'Questions Solved',
                value: '482',
                detail: 'Across tracks',
                icon: Icons.terminal,
                color: green,
              ),
              const MetricCard(
                title: 'Mock Tests Taken',
                value: '14',
                detail: 'This season',
                icon: Icons.fact_check,
              ),
              const MetricCard(
                title: 'Avg Mock Score',
                value: '84.5%',
                detail: 'Top percentile',
                icon: Icons.analytics,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SectionTitle(title: 'Skills Competency'),
          const SkillBar(label: 'Data Structures & Algo', value: .82),
          const SkillBar(label: 'Aptitude & Logic', value: .76),
          const SkillBar(label: 'Core CS (OS / DBMS / CN)', value: .70),
          const SkillBar(
            label: 'Interview Communication',
            value: .85,
            color: green,
          ),
          const SizedBox(height: 18),
          const SectionTitle(title: 'Target Companies'),
          const CompanyRow(name: 'Google', value: '70%', tag: 'Tier 1'),
          const CompanyRow(
            name: 'Microsoft',
            value: '82%',
            tag: 'High Priority',
          ),
          const CompanyRow(
            name: 'TCS Digital',
            value: '95%',
            tag: 'Assured Benchmark',
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description, color: blue),
                  title: const Text('Resume / Portfolio'),
                  subtitle: const Text('Updated Rahul_Sharma_SWE_2025.pdf'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => snack(context, 'Resume preview requested'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.hub, color: green),
                  title: Text('Placement Cell Sync'),
                  subtitle: Text('Central TPO Portal Integration'),
                  trailing: Text('Connected'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Notification Preferences'),
                  trailing: Switch(
                    value: state.notificationsEnabled,
                    onChanged: state.setNotificationsEnabled,
                  ),
                  onTap: () => state.setNotificationsEnabled(
                    !state.notificationsEnabled,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: state.logout,
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Log Out', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}

class AppPage extends StatelessWidget {
  const AppPage({required this.title, required this.child, super.key});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        elevation: 1,
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: ListTile(
            leading: Image.asset(
              'assets/placement_tracker_logo.png',
              width: 36,
            ),
            title: const Text(
              'PrepTrack',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(title),
            trailing: Builder(builder: (context) {
              final shell = context.findAncestorWidgetOfExactType<AppShell>();
              final token = shell?.state.api.authToken;
              if (token == null) return const Icon(Icons.notifications_none);
              final service = NotificationService(baseUrl: PlacementApi.baseUrl, token: token);
              return FutureBuilder<int>(
                future: service.unreadCount(),
                builder: (context, snapshot) => Badge(
                  isLabelVisible: (snapshot.data ?? 0) > 0,
                  label: Text('${snapshot.data ?? 0}'),
                  child: IconButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(service: service))),
                    icon: const Icon(Icons.notifications_none),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
      Expanded(child: child),
    ],
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.text, super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xffd5e0f8),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        color: navy,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class GradientCard extends StatelessWidget {
  const GradientCard({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: const LinearGradient(colors: [blue, blueContainer]),
    ),
    child: child,
  );
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({required this.text, super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xffe8eef8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        style: const TextStyle(
          color: navy,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({required this.title, this.subtitle, super.key});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (subtitle != null)
          Text(subtitle!, style: const TextStyle(color: muted, fontSize: 13)),
      ],
    ),
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    this.color = blue,
    this.wide = false,
    super.key,
  });
  final String title, value, detail;
  final IconData icon;
  final Color color;
  final bool wide;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({required this.value, this.color = blue, super.key});
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: LinearProgressIndicator(
      value: value,
      minHeight: 8,
      color: color,
      backgroundColor: Colors.white24,
    ),
  );
}

class DriveTile extends StatelessWidget {
  const DriveTile({
    required this.company,
    required this.detail,
    required this.days,
    super.key,
  });
  final String company, detail, days;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: blue.withAlpha(25),
        child: Text(
          company[0],
          style: const TextStyle(color: blue, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(company, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(detail),
      trailing: FilledButton(
        onPressed: () => snack(context, 'Preparation opened for $company'),
        child: Text(days),
      ),
    ),
  );
}

class TaskRow extends StatelessWidget {
  const TaskRow({
    required this.task,
    required this.state,
    this.detailed = false,
    super.key,
  });
  final Task task;
  final AppState state;
  final bool detailed;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: IconButton(
        onPressed: () => state.toggleTask(task),
        icon: Icon(
          task.completed ? Icons.check_circle : Icons.circle_outlined,
          color: task.completed ? green : muted,
        ),
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: task.completed ? TextDecoration.lineThrough : null,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${task.category} • +${task.xp} XP${detailed ? ' • ${task.completed ? 'Completed today' : 'Pending'}' : ''}',
      ),
      trailing: detailed
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!task.completed)
                  TextButton(
                    onPressed: () => state.toggleTask(task),
                    child: const Text('Complete'),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value != 'delete' || !context.mounted) return;
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Delete task?'),
                        content: Text('Remove "${task.title}" permanently?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      final deleted = await state.deleteTask(task);
                      if (context.mounted) snack(context, deleted ? 'Task deleted' : 'Unable to delete task');
                    }
                  },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete'))],
                ),
              ],
            )
          : null,
    ),
  );
}

class PracticeCard extends StatelessWidget {
  const PracticeCard({
    required this.title,
    required this.detail,
    required this.resume,
    super.key,
  });
  final String title, detail;
  final bool resume;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(detail, style: const TextStyle(color: muted)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () =>
                  snack(context, '${resume ? 'Resuming' : 'Starting'} $title'),
              icon: Icon(resume ? Icons.replay : Icons.play_arrow),
              label: Text(resume ? 'Resume Practice' : 'Start Practice'),
            ),
          ),
        ],
      ),
    ),
  );
}

class MockCard extends StatelessWidget {
  const MockCard({
    required this.title,
    required this.detail,
    required this.action,
    this.onPressed,
    super.key,
  });
  final String title, detail, action;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.auto_awesome, color: blue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(detail),
      trailing: FilledButton(
        onPressed: onPressed ?? () => showMockSession(
              context,
              title: title,
              detail: detail,
              action: action,
            ),
        child: Text(action),
      ),
    ),
  );
}

class HistoryCard extends StatelessWidget {
  const HistoryCard({
    required this.title,
    required this.score,
    required this.percentile,
    super.key,
  });
  final String title, score, percentile;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('$score • $percentile'),
      trailing: TextButton(
        onPressed: () => showMockResult(
          context,
          title: title,
          score: score,
          percentile: percentile,
        ),
        child: const Text('View Result'),
      ),
    ),
  );
}

class SkillBar extends StatelessWidget {
  const SkillBar({
    required this.label,
    required this.value,
    this.color = blue,
    super.key,
  });
  final String label;
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ProgressBar(value: value, color: color),
      ],
    ),
  );
}

class CompanyRow extends StatelessWidget {
  const CompanyRow({
    required this.name,
    required this.value,
    required this.tag,
    super.key,
  });
  final String name, value, tag;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: blue.withAlpha(25),
        child: Text(
          name[0],
          style: const TextStyle(color: blue, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(tag),
      trailing: Text(
        value,
        style: const TextStyle(color: blue, fontWeight: FontWeight.bold),
      ),
    ),
  );
}

class Field extends StatelessWidget {
  const Field({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    super.key,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?) validator;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator: validator,
    decoration: inputDecoration(label, icon),
  );
}

String? required(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required' : null;
InputDecoration inputDecoration(String label, IconData icon) => InputDecoration(
  labelText: label,
  prefixIcon: Icon(icon),
  filled: true,
  fillColor: const Color(0xfff2f4f6),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  ),
);
void snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );

void showMockSession(
  BuildContext context, {
  required String title,
  required String detail,
  required String action,
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail, style: const TextStyle(color: muted, height: 1.4)),
          const SizedBox(height: 16),
          const Text(
            'Your session is ready. Start when you are prepared.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(dialogContext);
            showDialog<void>(
              context: context,
              builder: (sessionContext) => AlertDialog(
                title: Text('$action Started'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, color: blue, size: 42),
                    const SizedBox(height: 12),
                    Text('$title is now active.', textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text(
                      'Complete the session to receive your performance result.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
                actions: [
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(sessionContext);
                      snack(
                        context,
                        '$title completed. Result is available in Recent Mock History.',
                      );
                    },
                    child: const Text('Complete Session'),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.play_arrow),
          label: Text(action),
        ),
      ],
    ),
  );
}

void showMockResult(
  BuildContext context, {
  required String title,
  required String score,
  required String percentile,
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, color: green, size: 42),
          const SizedBox(height: 12),
          Text(
            score,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: green,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cohort percentile: $percentile',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 14),
          const LinearProgressIndicator(
            value: .86,
            minHeight: 8,
            borderRadius: BorderRadius.all(Radius.circular(8)),
            color: green,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void showEditProfile(BuildContext context, AppState state) {
  final name = TextEditingController(text: state.profileName);
  final rollNumber = TextEditingController(text: state.profileRollNumber);
  final cgpa = TextEditingController(text: state.profileCgpa);
  final degree = TextEditingController(text: state.profileDegree);
  final formKey = GlobalKey<FormState>();

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Edit Profile'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Field(
                controller: name,
                label: 'Full Name',
                icon: Icons.person,
                validator: required,
              ),
              const SizedBox(height: 10),
              Field(
                controller: rollNumber,
                label: 'College Roll No.',
                icon: Icons.badge,
                validator: required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: cgpa,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final parsed = double.tryParse(value ?? '');
                  return parsed == null || parsed < 0 || parsed > 10
                      ? 'Enter a CGPA from 0 to 10'
                      : null;
                },
                decoration: inputDecoration('CGPA', Icons.school),
              ),
              const SizedBox(height: 10),
              Field(
                controller: degree,
                label: 'Degree',
                icon: Icons.account_balance,
                validator: required,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            state.updateProfile(
              name: name.text,
              rollNumber: rollNumber.text,
              cgpa: cgpa.text,
              degree: degree.text,
            );
            Navigator.pop(dialogContext);
            snack(context, 'Profile updated');
          },
          child: const Text('Save Changes'),
        ),
      ],
    ),
  );
}

Future<void> showAddTask(BuildContext context, AppState state) async {
  final title = TextEditingController();
  String category = 'Coding & DSA';
  final created = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('New Study Goal'),
      content: StatefulBuilder(
        builder: (context, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: inputDecoration('Task Title', Icons.title),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: inputDecoration('Category', Icons.category),
              items: const [
                'Coding & DSA',
                'Aptitude',
                'Tech Core',
                'HR / Soft Skills',
              ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
              onChanged: (value) => setDialogState(() => category = value!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            state.addTask(title.text, category);
            Navigator.pop(dialogContext, true);
          },
          child: const Text('Create Milestone'),
        ),
      ],
    ),
  );
  title.dispose();
  if (created == true && context.mounted) {
    snack(context, 'Task added to Actionable Tasks');
  }
}
