# Notificaciones del camionero — plan de la app nativa

> Estado: **aprobado el 2026-10-09** y **en implementación**. Es la fase **F5** de
> `PLAN_APP_CAMIONERO.md` §12.
>
> **Qué se cambió respecto al plan original (2026-10-09, mismo día):**
> 1. La vía principal es **FCM**, no `WorkManager`: el dueño pidió que el pedido no envejezca, y
>    `WorkManager` tiene piso de 15 min *y* lo que agregue Doze cuando el teléfono está quieto.
>    `WorkManager` queda como **respaldo opcional** (N4).
> 2. El identificador es el **registration token**, no el FID: `firebase_messaging` 16.7.0 **no expone
>    los Firebase Installation IDs** (`onRegistered`/`register()` no existen). La v1 de FCM acepta el
>    token durante la transición (`mockups/api/dispositivos.py`).
> 3. **Sí toca el backend**: sin infraestructura nueva no hay aviso inmediato. Ya está hecho y subido en
>    `gas_project` (migración `0038`, endpoints `/api/v1/dispositivos/` y `/baja/`, envío HTTP v1).
>
> **Implementado y verificado:** backend completo (31 tests + 109 con `test_movil`, en verde) y cliente
> Flutter sin errores de análisis. **Falta:** compilar en el teléfono, la credencial de servicio de
> Firebase y la prueba real de un aviso.

## 1. Decisiones cerradas

| Punto | Decisión | Motivo |
|---|---|---|
| Ruta técnica | **FCM (`firebase_messaging`) con notificación del sistema**; `WorkManager` como respaldo opcional | Aviso en 1-3 s y **menos** batería que hacer *polling*: reutiliza la conexión que Android ya mantiene. El plan original (`WorkManager` 15 min) se descartó al pedirse la menor latencia posible |
| Disparador | **Pendientes nuevos del pool** | Mismo criterio que la web: `estado='pendiente'`, `origen` de teléfono/tarreo, `entregador` nulo, fecha de hoy |
| Backend | **No se toca.** Se reutiliza `GET /api/v1/entregas/` | ~9 MB/mes por camionero con 15 min: ruido en un plan móvil. La opción B (endpoint `/novedades/`) queda condicionada a lo que mida el piloto |
| Frecuencia | **15 min** (piso que permite Android; es "al menos", no exacto) | Con 2 camioneros que no compiten por el pool, la latencia no cuesta ventas |
| Ventana | **08:00–20:00 (D-15)**, traída del servidor | Evita avisos inútiles a las 22:00 o 06:00 |
| Fuera de ventana | Si hay pedidos **`en_ruta`**, el trabajo **sigue activo** hasta cerrarlos | El camionero que sigue trabajando a las 20:30 necesita enterarse |

**Restricciones que se respetan** (`gas_project/docs/API_MOVIL.md` §2): no se modifica
`notificar_nuevo_pedido`, ni `VAPID_*`, ni `PushSubscription`, ni `views/push.py`, ni migraciones
aplicadas (≤ `0035_ubicacioncamion`), ni CSP, ni auth/2FA/`AXES_*`. Este plan es **aditivo** y
concentrado en `mobile/`.

## 2. Por qué no se reutiliza Web Push

El endpoint de Web Push pertenece al **navegador**, no al dispositivo: `pywebpush` no puede entregar
a Flutter, y un `WebView` no conserva el Service Worker con la app cerrada. La PWA del camionero
sigue con Web Push intacto (convivencia indefinida, D-2). La app nativa **no** se suscribe a Web
Push, así que no hay doble aviso mientras el camionero use una sola vía.

## 3. Arquitectura

```
WorkManager (15 min, red disponible)
        │
        ▼
trabajo_verificacion.dart   ← isolate de background (@pragma('vm:entry-point'))
        │  AlmacenSesionSeguro (misma credencial que la app)
        ▼
ApiCliente.restaurarSesion() → listarEntregas()      [GET /api/v1/entregas/]
        │
        ▼
decidir_aviso()   ← función PURA: (pendientes, ids avisados, hora servidor, última actividad)
        │
        ├── false → no hace nada (y actualiza última comprobación)
        └── true  → ServicioNotificaciones.mostrar()  +  memoria_pendientes.guardar()
```

| Archivo (nuevo, `mobile/lib/core/notificaciones/`) | Responsabilidad única |
|---|---|
| `decidir_aviso.dart` | Regla de negocio **pura y testeable** sin Flutter: ¿hay que avisar? ¿qué texto? |
| `memoria_pendientes.dart` | Snapshot local de ids ya avisados y hora de la última actividad de la app |
| `servicio_notificaciones.dart` | Canal, permiso `POST_NOTIFICATIONS`, mostrar. Interfaz + implementación (sustituible por un doble) |
| `programador_trabajo.dart` | Registrar/cancelar el trabajo periódico y decidir la ventana vigente |
| `trabajo_verificacion.dart` | Punto de entrada del isolate: compone las piezas anteriores |

Cambios en archivos existentes:

| Archivo | Cambio |
|---|---|
| `mobile/lib/app.dart` | Pedir el permiso tras el primer login; programar el trabajo al iniciar sesión y cancelarlo al cerrarla; escribir la hora de última actividad en `didChangeAppLifecycleState` |
| `mobile/lib/widgets/` | Botón *refrescar* manual (hoy solo recarga al entrar a la pestaña) |
| `mobile/pubspec.yaml` | `workmanager`, `flutter_local_notifications`, `shared_preferences` |
| `mobile/android/app/src/main/AndroidManifest.xml` | `POST_NOTIFICATIONS`; verificar si el plugin de `workmanager` ya aporta `RECEIVE_BOOT_COMPLETED` por *merge* (si no, agregarlo) |

Reglas de diseño que se aplican: `decidir_aviso()` es pura (DIP + SRP, se prueba con
`dart-add-unit-test` sin emulador); `ServicioNotificaciones` es una interfaz para poder inyectar un
doble; el trabajo de background no contiene reglas de negocio, solo composición.

## 4. Fases

### N0 — Spike (medio día). Decide el resto

Único riesgo serio: **¿`flutter_secure_storage` lee la sesión desde el isolate de background de
`WorkManager`?** Sin cookie no hay sesión y no hay aviso.

Pasos: trabajo periódico mínimo (1 disparo) → `restaurarSesion()` → `listarEntregas()` → notificación
local visible **con la app cerrada**.

- ✔ Cierre: notificación visible en el S22 con la app cerrada.
- ✖ Si falla y no hay arreglo razonable: **se replantea a FCM (N4)** y este documento se reescribe.

### N1 — Permiso, canal y refresco

Canal "Pedidos" (importancia alta, sonido y vibración), permiso `POST_NOTIFICATIONS` pedido una sola
vez tras el primer login con texto que explique para qué sirve, y botón *refrescar* manual.

- ✔ Cierre: en un teléfono Android 13+ recién instalado, tras el login aparece el diálogo del
  permiso; al concederlo, una notificación de prueba del canal se ve y suena.

### N2 — Trabajo periódico

`WorkManager` periódico con `NetworkType.connected`, nombre único, `ExistingPeriodicWorkPolicy.keep`;
cancelación en el cierre de sesión; ventana 08:00–20:00 extendida mientras haya pedidos `en_ruta`;
comparación contra el snapshot de ids avisados.

- ✔ Cierre: creado un pedido desde la web, el camionero recibe el aviso en ≤ 15 min **con la app
  cerrada**, y no vuelve a recibirlo si el pedido sigue pendiente. Creado a las 20:30 sin pedidos
  `en_ruta`: no avisa.

### N3 — Pulido y medición

Exención de optimización de batería (Doze y Samsung retrasan el trabajo), dedupe fina, texto del
aviso, 401 → el trabajo se detiene en silencio (sesión vencida a las 48 h), y medición real de
batería y datos durante el piloto.

- ✔ Cierre: una jornada completa en ruta sin batería anómala y sin avisos duplicados.

### N4 — FCM, solo si el piloto lo justifica

Solo si 15 min hacen perder un pedido. Implica backend: tabla `DispositivoPush` (migración **0036**),
`POST /api/v1/dispositivos/`, `notificar_nuevo_pedido_movil()` en módulo aparte, `firebase-admin`,
`google-services.json` y credenciales nuevas en Render.

## 5. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| El isolate de background no lee el almacén cifrado | N0 antes de escribir nada más; si falla, N4 |
| Doze o Samsung retrasan el trabajo | Exención de batería; el intervalo se interpreta como "al menos" y la ventana acota el daño |
| Aviso duplicado con la PWA | La app no registra Web Push; el camionero usa una sola vía |
| Ruido cada 15 min | Solo se avisa si el conjunto de pendientes cambió; y no se avisa con la app en primer plano (ya se refresca) |
| Sesión vencida (48 h) | 401 → el trabajo se cancela sin molestar al usuario |
| Consumo de datos mayor al estimado | Se mide en el piloto; si molesta, se abre la opción B (endpoint `/novedades/`) |

## 6. Fuera de alcance

Seguimiento GPS (§6 del plan general, fase F9), telemetría de fallos (D-12), actualización de la app
(D-13), notificaciones para otros roles, y cualquier función de negocio que la web no tenga.

## 7. Falta verificar en N0

1. `flutter_secure_storage` en el isolate de background.
2. Si el plugin de `workmanager` ya declara `RECEIVE_BOOT_COMPLETED` por *merge* de manifiesto.
3. Comportamiento real de Doze en el S22 con exención de batería concedida.
4. Si el toque en la notificación abre la app en frío y deja la pestaña de entregas visible.
