---
title: API Reference
---

# API Reference

The CDM library exposes a C API for integration with any language that supports C foreign function interfaces.

## Header

```c
#include <cdm/CDM.h>
```

## Version

```c
#define CDM_VERSION 10200
#define CDM_VERSION_STRING "1.2.0"
```

The version macro encodes `major * 10000 + minor * 100 + patch`.

## Types

### `cdm_model_t`

Opaque type representing a CDM model instance.

```c
struct cdm_model_s;
typedef struct cdm_model_s cdm_model_t;
```

### `cdm_error_handler_t`

Function pointer type for custom error handlers.

```c
typedef void (*cdm_error_handler_t)(const char *format, ...);
```

## Functions

### `cdm_set_error_handler`

Set a custom error handler function for CDM library routines.

```c
CDM_EXPORT cdm_error_handler_t cdm_set_error_handler(cdm_error_handler_t handler);
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `handler` | `cdm_error_handler_t` | Error handler function |

**Returns:** Previous error handler function.

---

### `cdm_create_model`

Initialize a new CDM model object from JSON-formatted configuration data.

```c
CDM_EXPORT cdm_model_t * cdm_create_model(const char *config);
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `config` | `const char *` | JSON configuration string |

**Returns:** Pointer to the created `cdm_model_t` object.

---

### `cdm_free_model`

Free memory associated with a CDM model object.

```c
CDM_EXPORT void cdm_free_model(cdm_model_t *model);
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `model` | `cdm_model_t *` | CDM model object |

---

### `cdm_run_model`

Run a CDM model simulation.

```c
CDM_EXPORT int cdm_run_model(cdm_model_t *model);
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `model` | `cdm_model_t *` | CDM model object |

**Returns:** Status code (`0` = success).

---

### `cdm_print_report`

Print model summary to stdout.

```c
CDM_EXPORT void cdm_print_report(cdm_model_t *model);
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `model` | `cdm_model_t *` | CDM model object |

---

### `cdm_get_output_string`

Allocate and return a string with JSON-formatted model results.

```c
CDM_EXPORT char * cdm_get_output_string(cdm_model_t *model);
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `model` | `cdm_model_t *` | CDM model object |

**Returns:** JSON string. Must be freed with `cdm_free_string`.

---

### `cdm_free_string`

Free memory associated with a string allocated by the CDM library.

```c
CDM_EXPORT void cdm_free_string(char *s);
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `s` | `char *` | String to free |

---

### `cdm_library_version`

Return the CDM library version string.

```c
CDM_EXPORT const char * cdm_library_version(void);
```

**Returns:** Version string (e.g., `"1.2.0"`).

## Export Macros

The `CDM_EXPORT` macro handles symbol visibility across platforms:

| Configuration | Behavior |
|---------------|----------|
| `CDM_STATIC_DEFINE` defined | No export decoration (static library) |
| `CDM_EXPORTS` defined | Symbols exported (building shared library) |
| Neither defined | Symbols imported (using shared library) |

## Usage Example

```c
#include <stdio.h>
#include <cdm/CDM.h>

int main() {
    // Read JSON config from file (simplified)
    const char *config = "{ ... }";

    // Create and run model
    cdm_model_t *model = cdm_create_model(config);
    if (!model) {
        fprintf(stderr, "Failed to create model\n");
        return 1;
    }

    int status = cdm_run_model(model);
    if (status != 0) {
        fprintf(stderr, "Model run failed with status %d\n", status);
        cdm_free_model(model);
        return 1;
    }

    // Print report to console
    cdm_print_report(model);

    // Get JSON output
    char *output = cdm_get_output_string(model);
    printf("JSON Output:\n%s\n", output);
    cdm_free_string(output);

    // Clean up
    cdm_free_model(model);
    return 0;
}
```
