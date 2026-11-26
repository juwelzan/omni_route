# Architecture, Lifecycle & Bloc Ownership

## 1. Layers

```
┌───────────────────────── your app ─────────────────────────┐
│ OmniApp(routes, blocs, guards)    Omni*Widget screens       │
│ OmniRoute.go / push / to<S>()     provide => [Provide<B>()] │
└──────────────┬──────────────────────────────┬──────────────┘
               │ built once                   │ declared
┌──────────────▼──────── OmniRoute ────────────▼──────────────┐
│ OmniPage        → GoRoute         OmniBlocRegistry (factories)│
│ OmniShell       → ShellRoute      OmniBlocScope  → MultiBlocProvider
│ OmniStatefulShell → StatefulShellRoute.indexedStack           │
│ OmniRouteGroup  → ShellRoute (no layout) + route-scoped Blocs │
│ OmniGuard       → GoRouter redirect   OmniPageConfig (per app)│
└──────┬─────────────────────────────────────────┬────────────┘
       │ plain go_router objects                 │ plain providers
┌──────▼──────── go_router ───────┐   ┌──────────▼── flutter_bloc ──┐
│ URL parsing, matching, stack,   │   │ BlocProvider create/value,  │
│ redirects, deep links, history, │   │ lazy creation, close on     │
│ restoration                     │   │ unmount, context.read/watch │
└─────────────────────────────────┘   └─────────────────────────────┘
```

OmniRoute owns no navigation stack and no state streams. Every OmniRoute
route is a go_router route, and every Bloc lives in a flutter_bloc provider.
What OmniRoute adds:

- validation at startup (paths, duplicate paths and names, Bloc registry)
- a page builder that puts a screen's Blocs **above** the screen, so they
  exist in its `initState` and `build`
- scopes: app, route group, shell, page, and screens shown outside routes
- per-app settings (page type, titles, error page)
- helpers (`OmniRoute.*`) and hooks (`onNavigate`)

## 2. Where each Bloc lives

| Scope | Declared with | Created / Registered | Closed | Survives |
|---|---|---|---|---|
| **Global** | `OmniBloc<B>(..., global: true)` on `OmniApp` | registered at `OmniApp` mount (created on mount if `lazy: false` or first read) | when `OmniApp` is disposed | everything |
| **Route group** | `OmniRouteGroup(provide: [...])` | registered & mounted on entering any route of the group | on leaving the group, or when `scopeKey` changes | moving between group routes; pages pushed on top |
| **Shell** | `OmniShell(provide:)` / `OmniStatefulShell(provide:)` | when the shell is first shown | when the shell is no longer shown | switching routes/tabs inside it |
| **Page** | screen `provide` / `OmniPage(blocs:)` (`OmniBloc(...)` or `Provide`) | registered & mounted on first entering the page | when the page is popped or replaced | rebuilds; pages pushed on top; hidden tabs |
| **Screen** | screen `provide` (shown outside a route) | registered & mounted when the screen mounts | when the screen is removed | rebuilds |
| **External** | `Provide.value(bloc)` | by you | **never by OmniRoute** | — |

### Ownership rules

1. A Bloc created by OmniRoute (`OmniBloc(...)`, `Provide<B>()`, `Provide.create`,
   global/group/shell entries) is closed by flutter_bloc's `BlocProvider`
   exactly once, when its owner leaves the tree. Page-scoped `OmniBloc`s are
   registered lazily into the app registry when their page is first entered.
2. `Provide.value` uses `BlocProvider.value`: never closed by OmniRoute.
3. Rebuilds never recreate a Bloc: providers sit in elements that survive
   rebuilds; pages are keyed by go_router's stable `pageKey`.
4. "Popped" means removed from the Navigator's page list. A page **covered**
   by another page, or a tab **hidden** in a stateful shell, is still
   mounted and keeps its Blocs.
5. A global Bloc can't also be provided by a screen; that is an error, so
   there is never a second, shadowing instance.

## 3. Lifecycle walkthrough

```
OmniApp.initState
  ├─ validate routes & Bloc registry (errors reported, ErrorWidget shown)
  ├─ GoRouter created once (owner: OmniApp)
  └─ onNavigate listener attached (if used)
OmniApp.build
  └─ OmniPageConfig ▸ global Bloc scope ▸ guard refresh ▸ your MaterialApp.router

go('/students/7')
  ├─ guards run (sync stays sync)       ← GoRouter redirect
  ├─ match → pages: /students, group, /students/7
  ├─ group page: OmniBlocScope(group Blocs) ▸ nested Navigator
  └─ page: OmniRouteStateScope ▸ OmniBlocScope(screen Blocs) ▸ title ▸ screen
       ├─ screen.initState  (Blocs already readable)
       └─ screen.build

push('/help')        → /students/7 stays mounted (Blocs alive)
pop()                → /help's page unmounts → its Blocs close
go('/settings')      → group & page unmount → their Blocs close
OmniApp.dispose      → listener removed, router disposed, global Blocs closed
```

## 4. Settings per app

Page type, title behaviour and the not-found page live in an inherited
widget under each `OmniApp`, so two apps (multi-window desktop, tests) never
share settings. `OmniRoute.*` helpers act on the most recently mounted app;
inside another app, use `context.go(...)`.

## 5. Guards are not security

Guards decide what the **UI** shows. Anyone can call your API directly, so
every permission a guard checks must also be enforced by your backend.
Guards should read state that is already loaded (e.g. an auth Bloc), not
call the network on every navigation.

## 6. Navigation observers

- Root navigator: `OmniApp(observers: [...])`.
- Shells: `OmniShell(observers: [...])`, `OmniRouteGroup(observers: [...])`,
  `StatefulShellBranch(observers: [...])` — go_router's own parameters.
- For most analytics, `OmniApp(onNavigate:)` is simpler: it sees every
  location change, including those inside shells.

## 7. Double taps

OmniRoute doesn't block repeated navigation, because some apps push the
same route twice on purpose. To ignore a second tap while a push is in
flight:

```dart
bool _busy = false;
Future<void> open() async {
  if (_busy) return;
  _busy = true;
  try {
    await OmniRoute.push('/students/7');
  } finally {
    _busy = false;
  }
}
```
