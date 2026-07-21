# MeshDraft

A mobile note-taking app where **the graph visualization is the product**, not a side feature.

Notes are linked to one another, and those relationships are rendered as a living force-directed graph — nodes bounce as they load, can be dragged, and their neighbours react. Built for knowledge workers who think in connections between ideas rather than in folders.

**Status:** MVP, local-only. All data lives in SQLite on the device. No accounts, no sync, no network.

---

## Screens

| Screen | Route | Contents |
|---|---|---|
| Notes List | `/notes` | Note grid, search, filters (all / linked / orphan) |
| Graph | `/graph` | Force simulation, pan & zoom, node dragging |
| Note Detail | `/note/:id` | Read & edit, list of linked notes |
| Create Note | `/create` | Note detail with the title auto-focused |
| Link Modal | `/note/:id/link` | Bottom sheet for linking to another note |

Notes and Graph are two tabs inside a `StatefulShellRoute` — each tab keeps its state when you switch away.

---

## Setup

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

**The `build_runner` step is not optional.** `*.g.dart` and `*.freezed.dart` files are deliberately not committed (see `.gitignore`), so a fresh clone **will not compile** until code generation has run. Drift, Riverpod, and Freezed all depend on it.

During development, leave watch mode running in a separate terminal:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

---

## Commands

```bash
flutter analyze                  # linter
flutter test                     # unit + widget + integration
dart format .                    # formatter
flutter run --profile            # required for graph profiling
```

Graph profiling **must** be done on a physical Android device with `--profile`. Debug mode is 3–10× slower and produces misleading numbers.

---

## Tech Stack

| Area | Choice |
|---|---|
| Framework | Flutter (iOS + Android) |
| State | Riverpod — `Notifier` / `AsyncNotifier` |
| Routing | go_router |
| Database | Drift (SQLite), local-only |
| Models | Freezed |
| Graph | `CustomPainter` + `InteractiveViewer`, hand-written force simulation |
| Styling | Material 3, dark theme |

---

## Structure

```
lib/
├── core/           theme, storage (Drift), cross-feature widgets & utils
├── features/
│   ├── note/       note CRUD
│   ├── link/       linking notes together
│   └── graph/      graph visualization
└── router/         go_router
```

Every feature uses the same layering:

```
data/{data_sources,repositories} → domain/models → application/services → presentation/{controllers,pages,widgets}
```

Business logic lives in `application/services`. Controllers only wire services to the UI.

---

## Data Model

Two tables, `Notes` and `NoteLinks`, with a cascading foreign key from links to notes.

`Notes.posX` / `posY` are nullable — `null` means the user has never moved that node, so its position is computed by the simulation. Once dragged, the position is persisted and the node becomes pinned.

---

## Decisions That Are Easy to Break

The four rules below **will not be caught by `flutter analyze`**. Breaking them produces code that looks correct but isn't.

**1. Links are normalized before being stored.** A link is semantically bidirectional, so `sourceId` is always the smaller id:

```dart
final (source, target) = a.compareTo(b) < 0 ? (a, b) : (b, a);
```

Without this, A→B and B→A are stored as two separate rows despite meaning the same thing, and `UNIQUE(sourceId, targetId)` won't catch it. This rule lives in `LinkService` — not in the UI, not in the repository.

**2. `PRAGMA foreign_keys = ON` in `beforeOpen`.** SQLite disables foreign keys by default. Without this pragma, `onDelete: cascade` never fires and orphaned links pile up every time a note is deleted.

**3. Reads always come from local.** Drift is the single source of truth. There is no `try remote → catch → local` pattern.

**4. Watch, don't refresh.** Controllers consume Drift `Stream`s. Don't re-run a query after a write — Drift emits the new list on its own:

```dart
// ✗ duplicate query, loading flicker
await service.createNote(...);
await _loadNotes();

// ✓
await service.createNote(...);
```

---

## Graph Rendering

`CustomPainter` + `InteractiveViewer` with a hand-written force simulation. **Not `graphview`.**

The reason isn't performance — both clear the target with plenty of headroom. The reason is that the graph has to feel *alive*. `graphview` computes its layout once at init and then the simulation is dead: no bouncing, and dragging snaps instead of flowing.

Performance target: **≤16ms (60fps) while panning with the simulation running, 100 nodes**, measured on a physical Android device in profile mode.

### Physics constants

The constants in `graph_layout_service.dart` (`kForceScale`, `kVelocityDamping`, `kTemperatureCutoff`, `kIdealDistance`, `kRepulsionCutoffFactor`, and others) **must not be changed without re-measuring.** Every number came out of a real bug; the long comments above them explain which one. Those comments are kept on purpose.

If a change really is needed:

1. Print `temp`, `maxSpeed`, `maxRawDisp`, and `bounds` every 60 frames
2. Confirm `temp` reaches 0 and `bounds` freezes — that's convergence
3. Confirm `maxSpeed` is **not** identical to the previous frame's `temp`. If it is, motion is being driven by the speed cap rather than by physics, and it will look coarse

### Rendering pitfalls

- **Don't clamp node positions to the screen size.** A force-directed layout has to be free to spread out; `InteractiveViewer` handles navigation. Clamping piles nodes up against the edges and makes them jitter.
- **`InteractiveViewer` requires `constrained: false`.** The default `true` squeezes the content into the viewport until the screen looks empty.
- **Don't derive the initial transform from `renderBox.size`.** The first frame can report a (0,0) viewport and poison the transform permanently.
- **`CustomPaint` uses `repaint:` hooked to an `AnimationController`**, not `setState()` per frame.
- **The `Random` instance is stored as a field with a fixed seed** — determinism is what makes measurements comparable between runs.

---

## Tests

```bash
flutter test
```

Coverage spans unit (services & layout), widget (pages & components), and integration (cascade delete, node position persistence).

`LinkService` is the top priority — it's where the normalization rule lives, and the only place a bidirectional-duplicate bug can slip through unnoticed. Test it from both directions: link A→B, then try B→A; the second one must be rejected.

---

## Out of MVP Scope

Scheduled for later phases and **deliberately not built yet**: auth, Supabase, sync, a settings screen, a manual theme toggle, AI auto-linking, Cornell Notes, tags, rich text, and landscape/tablet layouts.
