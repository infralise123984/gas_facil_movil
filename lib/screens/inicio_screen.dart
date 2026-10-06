import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pantalla de inicio.
///
/// Espejo de `index.html` para el rol camionero: logo, reloj y tres accesos
/// (Entregas Pendientes, Mis Entregas Hoy, Historial de Ventas).
class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key, required this.onIrAPestana});

  final ValueChanged<int> onIrAPestana;

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  late Timer _reloj;
  DateTime _ahora = DateTime.now();

  @override
  void initState() {
    super.initState();
    // TODO(api): la PWA muestra la hora del SERVIDOR (`hora_servidor`).
    // Se reemplaza por el campo `servidor_ahora` que devolverá cada endpoint.
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _ahora = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _reloj.cancel();
    super.dispose();
  }

  String get _horaTexto {
    String dos(int valor) => valor.toString().padLeft(2, '0');
    return '${dos(_ahora.hour)}:${dos(_ahora.minute)}:${dos(_ahora.second)}';
  }

  String get _fechaTexto {
    const List<String> dias = <String>[
      'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
    ];
    const List<String> meses = <String>[
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final int diaSemana = _ahora.weekday - 1;
    return '${dias[diaSemana]} ${_ahora.day} de ${meses[_ahora.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MedidasApp.anchoMaximoContenido),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 116,
                  height: 116,
                  decoration: const BoxDecoration(
                    color: ColoresApp.primario,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6)),
                    ],
                  ),
                  child: const Icon(Icons.local_fire_department, size: 62, color: Colors.white),
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: ColoresApp.grisClaro,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.access_time, size: 18, color: ColoresApp.secundario),
                          const SizedBox(width: 8),
                          Text(
                            _horaTexto,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fechaTexto,
                        style: const TextStyle(fontSize: 13, color: ColoresApp.secundario),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Provisorio: en la maqueta es la hora del teléfono.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: ColoresApp.secundario),
              ),
              const SizedBox(height: 26),
              const Text(
                'Bienvenido, Camionero',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kim Gas · Rancagua',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: ColoresApp.secundario),
              ),
              const SizedBox(height: 26),
              _AccesoTile(
                icono: Icons.local_shipping,
                titulo: 'Entregas Pendientes',
                subtitulo: 'Pedidos por repartir',
                color: ColoresApp.primario,
                onTap: () => widget.onIrAPestana(1),
              ),
              const SizedBox(height: 14),
              _AccesoTile(
                icono: Icons.check_circle,
                titulo: 'Mis Entregas Hoy',
                subtitulo: 'Tu ruta del día',
                color: ColoresApp.primario,
                onTap: () => widget.onIrAPestana(2),
              ),
              const SizedBox(height: 14),
              _AccesoTile(
                icono: Icons.calendar_month,
                titulo: 'Historial de Ventas',
                subtitulo: 'Ventas anteriores',
                color: ColoresApp.secundario,
                onTap: () => _historialPendiente(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _historialPendiente() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('El historial llega en una fase posterior (F6).',
            style: TextStyle(fontSize: 16)),
      ),
    );
  }
}

/// Tarjeta de acceso del menú, espejo de `.menu-tile` en `index.html`.
class _AccesoTile extends StatelessWidget {
  const _AccesoTile({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.color,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE9ECEF)),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icono, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    titulo,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitulo,
                    style: const TextStyle(fontSize: 14, color: ColoresApp.secundario),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFC3C9D1), size: 26),
          ],
        ),
      ),
    );
  }
}
