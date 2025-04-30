import 'package:flutter/material.dart';
import 'package:flutter_pfe/presentation/home/home.dart';
import 'package:flutter_pfe/presentation/login/view/login.dart';
import 'package:flutter_pfe/presentation/meething/meething.dart';
import 'package:flutter_pfe/presentation/navigationbottombar/view/navigationbottombar.dart';
import 'package:flutter_pfe/presentation/profile/profile.dart';
import 'package:flutter_pfe/presentation/problemsmanage/problem.dart';
import 'package:flutter_pfe/presentation/usersmange/users.dart';
import 'package:flutter_pfe/presentation/project/project.dart';
import 'package:flutter_pfe/presentation/worker_dashboard/worker_navigation.dart';

class Routes {
  static const String splashRoute = "/";
  static const String loginRoutes = "/login";
  static const String onBoardingRoute = "/onBoarding";
  static const String registerRoute = "/register";
  static const String forgotPasswordRoute = "/forgotPassword";
  static const String mainRoute = "/main";
  static const String storeDetailsRoute = "/storeDetails";
  static const String projectRoute = "/project";
  static const String usersRoute = "/users";
  static const String workerNavigationRoute = "/worker-navigation";
  static const String homeRoutes = "/home";
  static const String problemsRoutes = "/problems";
  static const String meethings = "/meethings";
  static const String profileRoutes = "/profile";
  static const String favorite = "/favorite";
}

class RouteGenerator {
  static Route<dynamic> getRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.loginRoutes:
        return MaterialPageRoute(builder: (_) => const Login());
      case Routes.mainRoute:
        return MaterialPageRoute(
          builder: (_) => const NavigationBottomBar(selectedProject: {}),
        );
      case Routes.projectRoute:
        return MaterialPageRoute(builder: (_) => const Project());
      case Routes.usersRoute:
        return MaterialPageRoute(
          builder: (_) => const Users(selectedProject: {}),
        );
      case Routes.workerNavigationRoute:
        return MaterialPageRoute(
          builder: (_) => WorkerNavigationBar(selectedProject: {}),
        );
      case Routes.homeRoutes:
        return MaterialPageRoute(builder: (_) => const HomePage());
      case Routes.problemsRoutes:
        return MaterialPageRoute(builder: (_) => const Problem());
      case Routes.meethings:
        return MaterialPageRoute(builder: (_) => const Meething());
      case Routes.profileRoutes:
        return MaterialPageRoute(builder: (_) => const Profile());
      default:
        return unDefinedRoute();
    }
  }

  static Route<dynamic> unDefinedRoute() {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('No Route Found'),
        ),
        body: const Center(
          child: Text('No Route Found'),
        ),
      ),
    );
  }
}
