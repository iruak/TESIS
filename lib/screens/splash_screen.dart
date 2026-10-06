import 'package:flutter/material.dart';
import 'bienvenida_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animación de entrada (fade / scale / slide) ──────────────
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _slideAnim;

  // ── Animación de rebote infinito de la flecha ────────────────
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();

    // ── Controller de entrada (1.2 s, una sola vez) ──
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
    );

    _scaleAnim = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _slideAnim = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    // ── Controller de rebote (loop infinito con reverse) ──
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _bounceAnim = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.easeInOut,
      ),
    );

    // Arranca la animación de entrada y, al terminar, lanza el rebote
    _controller.forward().whenComplete(() {
      if (mounted) {
        _bounceController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  // ── Navega a /bienvenida con transición slide desde abajo ─────
  void _irABienvenida() {
    final route = PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const BienvenidaScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1), // entra desde abajo
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    );
    Navigator.of(context).pushReplacement(route);
  }


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Swipe hacia arriba → navegar a /bienvenida
      onVerticalDragEnd: (details) {
        if (details.velocity.pixelsPerSecond.dy < -300) {
          _irABienvenida();
        }
      },
      // Tap también navega (UX alternativa por si el swipe es difícil)
      onTap: _irABienvenida,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1B5E20), // Verde oscuro profundo
                Color(0xFF2E7D32), // Verde rural principal
                Color(0xFF388E3C), // Verde medio
                Color(0xFF4E342E), // Tono tierra/marrón
              ],
              stops: [0.0, 0.35, 0.65, 1.0],
            ),
          ),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: Listenable.merge([_controller, _bounceController]),
              builder: (context, child) {
                return Stack(
                  children: [
                    // ── Elementos decorativos de fondo ──
                    Positioned(
                      top: -60,
                      right: -60,
                      child: Opacity(
                        opacity: _fadeAnim.value * 0.12,
                        child: Container(
                          width: 260,
                          height: 260,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -80,
                      left: -50,
                      child: Opacity(
                        opacity: _fadeAnim.value * 0.10,
                        child: Container(
                          width: 300,
                          height: 300,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),

                    // ── Contenido central ──
                    Center(
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo con escala animada
                            Transform.scale(
                              scale: _scaleAnim.value,
                              child: Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    width: 130,
                                    height: 130,
                                    fit: BoxFit.contain,
                                    errorBuilder: (ctx, err, stack) =>
                                        const Icon(
                                      Icons.water_drop_rounded,
                                      size: 72,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 36),

                            // Nombre de la app (con slide hacia arriba)
                            Transform.translate(
                              offset: Offset(0, _slideAnim.value),
                              child: const Text(
                                'Sistema de Ordeño',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  height: 1.1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Transform.translate(
                              offset: Offset(0, _slideAnim.value),
                              child: const Text(
                                'Inteligente',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Subtítulo
                            Transform.translate(
                              offset: Offset(0, _slideAnim.value),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Tecnología para el campo',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Flecha rebotante + texto "Desliza para continuar" ──
                    Positioned(
                      bottom: 40,
                      left: 0,
                      right: 0,
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          children: [
                            // Flecha con animación de rebote hacia arriba
                            Transform.translate(
                              offset: Offset(0, _bounceAnim.value),
                              child: Icon(
                                Icons.keyboard_arrow_up_rounded,
                                size: 40,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Desliza para continuar',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.60),
                                fontSize: 13,
                                letterSpacing: 1.0,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
