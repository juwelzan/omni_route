# omni_network_openapi

A dev tool that turns an OpenAPI 3.0/3.1 spec (JSON or YAML) into one Dart
file: models with `fromJson`/`toJson`, enums, and typed `Endpoint`s for
[`omni_network`](../omni_network).

```yaml
dev_dependencies:
  omni_network_openapi:
    git:
      url: https://github.com/juwelzan/omni_route.git
      path: packages/omni_network_openapi
      ref: v0.5.0   # use the same tag for every package from this repo
```

```sh
dart run omni_network_openapi -i openapi.yaml -o lib/api.g.dart [--name PetApi] [--no-format]
```

```dart
import 'api.g.dart';

final pets = await api.call(PetStoreApi.listPets, query: {'limit': 10});
final pet  = await api.call(PetStoreApi.showPetById, path: {'petId': 7});
await api.call(PetStoreApi.createPet, body: const NewPet(name: 'Rex').toJson());
PetStoreApi.registry.all;    // every endpoint, e.g. for mocks
```

## Mapping

| OpenAPI | Dart |
|---|---|
| `string` / `format: date-time` | `String` / `DateTime` |
| `integer` / `number` / `boolean` | `int` / `double` / `bool` |
| `array` | `List<T>` |
| `object` with `properties` | `final class` (nested ones become `ParentField`) |
| `additionalProperties` | `Map<String, T>` |
| `enum` (string) | `enum` that keeps the wire values (`soldOut('sold-out')`) |
| `allOf` | merged class |
| not `required`, `nullable`, `type: [x, "null"]` | nullable field |
| `oneOf` / `anyOf` | `Object?` (with a warning) |

Names are adjusted for Dart:

- `created_at` becomes `createdAt`, but the JSON key stays `created_at`;
- reserved words get a `$` (`class` → `class$`);
- `{pet-id}` in a path becomes `{petId}`.

## What it does not do

Each of these is reported as a `warning:` on stderr, never silently:

- Swagger 2;
- `$ref`s to other files;
- multipart request bodies (use `api.upload`);
- cookie parameters.

Header and query parameters are listed in each endpoint's doc comment.
Security schemes are not generated; configure auth on the client
(`BearerAuth`).

Exit codes: 64 for a usage error, 65 for an invalid spec, 66 when the file
is missing.
