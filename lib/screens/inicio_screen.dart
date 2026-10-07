import 'dart:async';

import 'package:flutter/material.dart';

import '../core/time/reloj_servidor.dart';
import '../theme/app_theme.dart';

/// Pantalla de inicio.
///
/// Espejo de `index.html` para el rol camionero: logo, reloj y tres accesos
/// (Entregas Pendientes, Mis Entregas Hoy, Historial de Ventas).
class InicioScreen extends StatefulWidget {
  const InicioScreen({
    super.key,
    required this.onIrAPestana,
    required this.nombreUsuario,
    required this.reloj,
    required this.onVerHistorial,
  });

  final ValueChanged<int> onIrAPestana;

  /// Nombre del camionero que tiene la sesión abierta, para el saludo.
  final String nombreUsuario;

  /// Hora del servidor: el reloj de la PWA no es el del teléfono.
  final RelojServidor reloj;

  /// Abre el historial de ventas. La navegación la arma el contenedor, que es
  /// quien tiene el cliente del API.
  final VoidCallback onVerHistorial;

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  late Timer _tictac;

  @override
  void initState() {
    super.initState();
    // Se avanza con el reloj del teléfono, pero partiendo de la hora del
    // servidor: cada respuesta del API reajusta el desfase (RelojServidor).
    _tictac = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tictac.cancel();
    super.dispose();
  }

  DateTime get _ahora => widget.reloj.ahora;

  String get _horaTexto {
    String dos(int valor) => valor.toString().padLeft(2, '0');
    return '${dos(_ahora.hour)}:${dos(_ahora.minute)}:${dos(_ahora.second)}';
  }

  String get _fechaTexto {
    const List<String> dias = <String>[
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
    const List<String> meses = <String>[
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
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
              // Sin respuesta del servidor todavía, el reloj es el del teléfono
              // y hay que decirlo. En cuanto llega la primera respuesta, el
              // aviso desaparece.
              if (!widget.reloj.sincronizado)
                const Text(
                  'Provisorio: todavía no llegó la hora del servidor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: ColoresApp.secundario),
                ),
              const SizedBox(height: 26),
              Text(
                'Bienvenido, ${widget.nombreUsuario}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
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
                onTap: widget.onVerHistorial,
              ),
            ],
          ),
        ),
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
                  Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
