# Shirube + Kaname shared shell

This directory is an opt-in composition example. Shirube and Kaname remain
independent packages; only their QML components share one Quickshell process.

Create a runtime directory containing this `shell.qml` and two links:

```text
shared/
├── shell.qml
├── Shirube -> /path/to/shirube/share/shirube
└── Kaname  -> /path/to/kaname/share/kaname/quickshell
```

Start the shared configuration instead of either standalone shell:

```sh
quickshell -p /path/to/shared
```

Point both CLIs at that same configuration:

```sh
SHIRUBE_QML_DIR=/path/to/shared shirube toggle audio
KANAME_QML_DIR=/path/to/shared kaname --applications
```

Do not run the standalone Shirube service or `kaname-shell` at the same time.
