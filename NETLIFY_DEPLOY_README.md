# WARZONE: LAST STAND — FINAL NETLIFY DEPLOY PACKAGE

This is the Godot 4.7.2 project prepared for Netlify Web export.

## IMPORTANT
Use this folder as the **root of a Netlify site/repository**. Netlify must run the included build command. Do not use Netlify's drag-and-drop "Deploy manually" area for this source ZIP; that mode expects an already-exported static web build.

The Netlify build automatically:
1. Downloads the official Godot 4.7.2 stable Linux editor.
2. Downloads the official Godot 4.7.2 export templates.
3. Imports the project.
4. Exports the existing Godot game using the `Web` preset.
5. Publishes the generated `web/` folder.

The game source and scene are retained as supplied. No game mechanics or UI were intentionally changed.

Godot's command-line export requires an export preset and installed export templates; this package supplies both. See the official Godot documentation for command-line exporting and export templates.
