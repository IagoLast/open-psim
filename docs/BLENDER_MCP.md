# Blender MCP

Este proyecto configura [Blender MCP](https://github.com/ahujasid/blender-mcp)
1.9.1 en [`.codex/config.toml`](../.codex/config.toml), con Python 3.11 gestionado
por `uv`, conexión local a `127.0.0.1:9876` y telemetría desactivada.
La configuración se aplica únicamente a este proyecto en Codex.

## Usar

1. Abre Blender. El complemento **MCP for Blender** está instalado y activado
   en Blender 5.2 y arranca su conexión automáticamente.
2. Abre una nueva sesión de Codex en este proyecto para cargar el MCP.
3. Pide, por ejemplo: «Usa Blender MCP para inspeccionar la escena actual».

Para comprobar la configuración desde la raíz del proyecto:

```sh
codex mcp get blender
```

Si no conecta, en la vista 3D de Blender pulsa `N`, abre **MCP for Blender**
y pulsa **Connect to Claude** (el botón conserva ese nombre también al usar
Codex). Blender debe permanecer abierto con su interfaz gráfica; el complemento
no admite `--background`.

## Reinstalar en otro equipo

Requiere Blender 3.0 o posterior y [uv](https://docs.astral.sh/uv/getting-started/installation/).
Instala el complemento de la misma versión que el servidor:

```sh
DISABLE_TELEMETRY=true UV_PYTHON_PREFERENCE=only-managed \
  uvx --python 3.11 blender-mcp==1.9.1 install-addon
```

En Blender, ve a **Edit → Preferences → Add-ons**, activa **MCP for Blender**
y desmarca **Allow Telemetry**. Guarda las preferencias.

Actualiza `command` en `.codex/config.toml` con la ruta que devuelve `command -v uvx`
en ese equipo. Codex carga la configuración local en proyectos de confianza;
consulta la [documentación oficial de OpenAI sobre MCP](https://developers.openai.com/codex/mcp).

El servidor y el complemento son herramientas de desarrollo; no son dependencias
del juego ni se incluyen en la exportación de Godot.
