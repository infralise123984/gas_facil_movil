import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Barra inferior del camionero.
///
/// Réplica exacta de la barra de `base.html`: cuatro destinos, con Tarreo
/// destacado en verde. No se agregan ni se quitan ítems.
class BarraNavegacionCamionero extends StatelessWidget {
  const BarraNavegacionCamionero({super.key, required this.indice, required this.onCambiar});

  final int indice;
  final ValueChanged<int> onCambiar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFDEE2E6))),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MedidasApp.alturaBarraInferior,
          child: Row(
            children: <Widget>[
              _ItemBarra(
                icono: Icons.home,
                etiqueta: 'Inicio',
                activo: indice == 0,
                onTap: () => onCambiar(0),
              ),
              _ItemBarra(
                icono: Icons.local_shipping,
                etiqueta: 'Entregas Pendientes',
                activo: indice == 1,
                onTap: () => onCambiar(1),
              ),
              _ItemBarra(
                icono: Icons.check_circle,
                etiqueta: 'Mis Entregas',
                activo: indice == 2,
                onTap: () => onCambiar(2),
              ),
              _ItemBarraTarreo(activo: indice == 3, onTap: () => onCambiar(3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemBarra extends StatelessWidget {
  const _ItemBarra({
    required this.icono,
    required this.etiqueta,
    required this.activo,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = activo ? ColoresApp.primario : ColoresApp.secundario;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icono, size: 28, color: color),
            const SizedBox(height: 3),
            Text(
              etiqueta,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarreo va destacado en verde, igual que en la PWA.
class _ItemBarraTarreo extends StatelessWidget {
  const _ItemBarraTarreo({required this.activo, required this.onTap});

  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: ColoresApp.exito,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const <Widget>[
              Icon(Icons.add_shopping_cart, size: 28, color: Colors.white),
              SizedBox(height: 3),
              Text(
                'Tarreo',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
