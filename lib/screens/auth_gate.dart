import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repo.dart';
import '../widgets/common.dart';
import 'auth_screen.dart';
import 'business_form_screen.dart';
import 'shell.dart';

/// Shows login when signed out, otherwise the business area.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session =
            snapshot.hasData ? snapshot.data!.session : auth.currentSession;
        if (session == null) return const AuthScreen();
        return BusinessGate(key: ValueKey(session.user.id));
      },
    );
  }
}

/// Loads the user's businesses; first-time users go to onboarding.
class BusinessGate extends StatefulWidget {
  const BusinessGate({super.key});

  @override
  State<BusinessGate> createState() => _BusinessGateState();
}

class _BusinessGateState extends State<BusinessGate> {
  late Future<List<Business>> _future;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _future = Repo.myBusinesses();
  }

  void _reload({String? select}) {
    setState(() {
      if (select != null) _selectedId = select;
      _future = Repo.myBusinesses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Business>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: LoadingView());
        }
        if (snap.hasError) {
          return Scaffold(
              body: ErrorView(error: snap.error!, onRetry: () => _reload()));
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return BusinessFormScreen(
            onCreated: (id) => _reload(select: id),
          );
        }
        final current = list.firstWhere(
          (b) => b.id == _selectedId,
          orElse: () => list.first,
        );
        return AppShell(
          key: ValueKey(current.id),
          business: current,
          allBusinesses: list,
          onSwitch: (id) => _reload(select: id),
          onChanged: () => _reload(select: current.id),
        );
      },
    );
  }
}
