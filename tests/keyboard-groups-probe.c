/* SPDX-License-Identifier: BSD-3-Clause
 * Copyright (c) 2026 SecurityOps contributors
 * Only run through the private compositor regression harness. */
#define _POSIX_C_SOURCE 200809L
#include "river-input-management-client-protocol.h"
#include "river-xkb-config-client-protocol.h"
#include "virtual-keyboard-client-protocol.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <wayland-client.h>
#include <xkbcommon/xkbcommon.h>

static struct wl_display *display;
static struct wl_seat *seats[8];
static unsigned seat_count, device_count;
static struct wl_keyboard *keyboard;
static struct river_input_manager_v1 *input;
static struct river_xkb_config_v1 *xkb;
static struct zwp_virtual_keyboard_manager_v1 *virtual_manager;
static int supplier, rate = -1, delay = -1, keymap_ready;
static xkb_keysym_t symbol;
struct device {
  struct river_input_device_v1 *object;
  struct river_xkb_keyboard_v1 *xkb;
  unsigned type;
  char name[128];
  int removed;
};
static struct device devices[16];

static void sync_events(void) {
  for (int i = 0; i < 3; i++)
    assert(wl_display_roundtrip(display) >= 0);
}
static void keymap(void *d, struct wl_keyboard *k, uint32_t format, int32_t fd,
                   uint32_t size) {
  (void)d;
  (void)k;
  assert(format == WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1);
  char *text = mmap(NULL, size, PROT_READ, MAP_PRIVATE, fd, 0);
  close(fd);
  assert(text != MAP_FAILED);
  struct xkb_context *ctx = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
  struct xkb_keymap *map = xkb_keymap_new_from_string(
      ctx, text, XKB_KEYMAP_FORMAT_TEXT_V1, XKB_KEYMAP_COMPILE_NO_FLAGS);
  munmap(text, size);
  assert(map);
  const xkb_keysym_t *syms;
  assert(xkb_keymap_key_get_syms_by_level(
             map, xkb_keymap_key_by_name(map, "AC10"), 0, 0, &syms) > 0);
  symbol = syms[0];
  xkb_keymap_unref(map);
  xkb_context_unref(ctx);
}
static void enter(void *d, struct wl_keyboard *k, uint32_t s,
                  struct wl_surface *w, struct wl_array *a) {
  (void)d;
  (void)k;
  (void)s;
  (void)w;
  (void)a;
}
static void leave(void *d, struct wl_keyboard *k, uint32_t s,
                  struct wl_surface *w) {
  (void)d;
  (void)k;
  (void)s;
  (void)w;
}
static void key(void *d, struct wl_keyboard *k, uint32_t s, uint32_t t,
                uint32_t c, uint32_t st) {
  (void)d;
  (void)k;
  (void)s;
  (void)t;
  (void)c;
  (void)st;
}
static void mods(void *d, struct wl_keyboard *k, uint32_t s, uint32_t a,
                 uint32_t b, uint32_t c, uint32_t g) {
  (void)d;
  (void)k;
  (void)s;
  (void)a;
  (void)b;
  (void)c;
  (void)g;
}
static void repeat(void *d, struct wl_keyboard *k, int32_t r, int32_t l) {
  (void)d;
  (void)k;
  rate = r;
  delay = l;
}
static const struct wl_keyboard_listener keyboard_listener = {
    keymap, enter, leave, key, mods, repeat};
static void caps(void *d, struct wl_seat *s, uint32_t c) {
  (void)d;
  if (!supplier && !keyboard && (c & WL_SEAT_CAPABILITY_KEYBOARD)) {
    keyboard = wl_seat_get_keyboard(s);
    wl_keyboard_add_listener(keyboard, &keyboard_listener, NULL);
  }
}
static void seat_name(void *d, struct wl_seat *s, const char *n) {
  (void)d;
  (void)s;
  (void)n;
}
static const struct wl_seat_listener seat_listener = {caps, seat_name};
static void device_removed(void *d, struct river_input_device_v1 *p) {
  (void)p;
  ((struct device *)d)->removed = 1;
}
static void device_type(void *d, struct river_input_device_v1 *p, uint32_t t) {
  (void)p;
  ((struct device *)d)->type = t;
}
static void device_name(void *d, struct river_input_device_v1 *p,
                        const char *n) {
  (void)p;
  snprintf(((struct device *)d)->name, 128, "%s", n);
}
static const struct river_input_device_v1_listener device_listener = {
    .removed = device_removed, .type = device_type, .name = device_name};
static void input_finished(void *d, struct river_input_manager_v1 *p) {
  (void)d;
  river_input_manager_v1_destroy(p);
}
static void input_device(void *d, struct river_input_manager_v1 *p,
                         struct river_input_device_v1 *o) {
  (void)d;
  (void)p;
  assert(device_count < 16);
  struct device *v = &devices[device_count++];
  v->object = o;
  v->type = 99;
  river_input_device_v1_add_listener(o, &device_listener, v);
}
static const struct river_input_manager_v1_listener input_listener = {
    input_finished, input_device};
static void xkb_removed(void *d, struct river_xkb_keyboard_v1 *p) {
  (void)d;
  (void)p;
}
static void xkb_device(void *d, struct river_xkb_keyboard_v1 *p,
                       struct river_input_device_v1 *i) {
  (void)d;
  for (unsigned n = 0; n < device_count; n++)
    if (devices[n].object == i)
      devices[n].xkb = p;
}
static void xkb_layout(void *d, struct river_xkb_keyboard_v1 *p, uint32_t n,
                       const char *s) {
  (void)d;
  (void)p;
  (void)n;
  (void)s;
}
static void xkb_flag(void *d, struct river_xkb_keyboard_v1 *p) {
  (void)d;
  (void)p;
}
static const struct river_xkb_keyboard_v1_listener xkb_keyboard_listener = {
    .removed = xkb_removed,
    .input_device = xkb_device,
    .layout = xkb_layout,
    .capslock_enabled = xkb_flag,
    .capslock_disabled = xkb_flag,
    .numlock_enabled = xkb_flag,
    .numlock_disabled = xkb_flag};
static void xkb_finished(void *d, struct river_xkb_config_v1 *p) {
  (void)d;
  river_xkb_config_v1_destroy(p);
}
static void xkb_keyboard(void *d, struct river_xkb_config_v1 *p,
                         struct river_xkb_keyboard_v1 *k) {
  (void)d;
  (void)p;
  river_xkb_keyboard_v1_add_listener(k, &xkb_keyboard_listener, NULL);
}
static const struct river_xkb_config_v1_listener xkb_listener = {xkb_finished,
                                                                 xkb_keyboard};
static void global(void *d, struct wl_registry *r, uint32_t n, const char *i,
                   uint32_t v) {
  (void)d;
  (void)v;
  if (!strcmp(i, "wl_seat")) {
    assert(seat_count < 8);
    seats[seat_count] = wl_registry_bind(r, n, &wl_seat_interface, 7);
    wl_seat_add_listener(seats[seat_count++], &seat_listener, NULL);
  }
  if (!strcmp(i, "river_input_manager_v1")) {
    input = wl_registry_bind(r, n, &river_input_manager_v1_interface, 1);
    river_input_manager_v1_add_listener(input, &input_listener, NULL);
  }
  if (!strcmp(i, "river_xkb_config_v1") && !supplier) {
    xkb = wl_registry_bind(r, n, &river_xkb_config_v1_interface, 1);
    river_xkb_config_v1_add_listener(xkb, &xkb_listener, NULL);
  }
  if (!strcmp(i, "zwp_virtual_keyboard_manager_v1") && supplier)
    virtual_manager =
        wl_registry_bind(r, n, &zwp_virtual_keyboard_manager_v1_interface, 1);
}
static void removed(void *d, struct wl_registry *r, uint32_t n) {
  (void)d;
  (void)r;
  (void)n;
}
static const struct wl_registry_listener registry_listener = {global, removed};
static int map_fd(const char *layout, uint32_t *size) {
  struct xkb_context *ctx = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
  struct xkb_rule_names names = {.layout = layout};
  struct xkb_keymap *map =
      xkb_keymap_new_from_names(ctx, &names, XKB_KEYMAP_COMPILE_NO_FLAGS);
  assert(map);
  char *text = xkb_keymap_get_as_string(map, XKB_KEYMAP_FORMAT_TEXT_V1);
  *size = strlen(text) + 1;
  char path[] = "/tmp/river-test-keymap-XXXXXX";
  int fd = mkstemp(path);
  assert(fd >= 0);
  unlink(path);
  assert(write(fd, text, *size) == (ssize_t)*size);
  free(text);
  xkb_keymap_unref(map);
  xkb_context_unref(ctx);
  return fd;
}
static void map_success(void *d, struct river_xkb_keymap_v1 *p) {
  (void)d;
  (void)p;
  keymap_ready = 1;
}
static void map_failure(void *d, struct river_xkb_keymap_v1 *p, const char *e) {
  (void)d;
  (void)p;
  fprintf(stderr, "keymap: %s\n", e);
  abort();
}
static const struct river_xkb_keymap_v1_listener map_listener = {map_success,
                                                                 map_failure};
static void set_map(struct device *d, const char *layout) {
  uint32_t size;
  int fd = map_fd(layout, &size);
  (void)size;
  keymap_ready = 0;
  struct river_xkb_keymap_v1 *map =
      river_xkb_config_v1_create_keymap(xkb, fd, 1);
  close(fd);
  river_xkb_keymap_v1_add_listener(map, &map_listener, NULL);
  sync_events();
  assert(keymap_ready && d->xkb);
  river_xkb_keyboard_v1_set_keymap(d->xkb, map);
  sync_events();
  river_xkb_keymap_v1_destroy(map);
}
static struct device *find_device(const char *name) {
  for (unsigned n = 0; n < device_count; n++)
    if (devices[n].type == 0 && !strcmp(devices[n].name, name))
      return &devices[n];
  fprintf(stderr, "missing device %s\n", name);
  abort();
}
static void expect(const char *label, int r, int d, xkb_keysym_t s) {
  sync_events();
  printf("%s: repeat=%d/%d symbol=%x\n", label, rate, delay, symbol);
  fflush(stdout);
  if (rate != r || delay != d || symbol != s) {
    fprintf(stderr, "expected repeat=%d/%d symbol=%x\n", r, d, s);
    exit(1);
  }
}
static void set_repeat(struct device *d, int r, int l) {
  river_input_device_v1_set_repeat_info(d->object, r, l);
  sync_events();
}
int main(int argc, char **argv) {
  assert(argc == 2);
  supplier = !strcmp(argv[1], "supply");
  assert(getenv("RIVER_PRIVATE_INPUT_TEST"));
  display = wl_display_connect(NULL);
  assert(display);
  struct wl_registry *registry = wl_display_get_registry(display);
  wl_registry_add_listener(registry, &registry_listener, NULL);
  sync_events();
  assert(input);
  if (supplier) {
    river_input_manager_v1_create_seat(input, "extra");
    sync_events();
    assert(seat_count == 2 && virtual_manager);
    struct zwp_virtual_keyboard_v1 *vk[2];
    uint32_t size;
    int fd = map_fd("br", &size);
    for (unsigned n = 0; n < 2; n++) {
      vk[n] = zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(
          virtual_manager, seats[n]);
      zwp_virtual_keyboard_v1_keymap(vk[n], 1, fd, size);
    }
    sync_events();
    close(fd);
    puts("READY");
    fflush(stdout);
    char line[64];
    while (fgets(line, sizeof(line), stdin)) {
      if (!strncmp(line, "remove", 6)) {
        zwp_virtual_keyboard_v1_destroy(vk[0]);
        sync_events();
        puts("REMOVED");
        fflush(stdout);
      } else
        break;
    }
  } else {
    struct device *a = find_device("wayland-keyboard-default"),
                  *b = find_device("wayland-keyboard-extra");
    expect("initial shared group", 40, 400, XKB_KEY_ccedilla);
    set_repeat(a, 25, 600);
    expect("split shared active group", 40, 400, XKB_KEY_ccedilla);
    set_repeat(b, 30, 700);
    expect("replace last active member", 30, 700, XKB_KEY_ccedilla);
    set_repeat(a, 15, 800);
    expect("change inactive group", 30, 700, XKB_KEY_ccedilla);
    set_repeat(a, 30, 700);
    expect("join active group", 30, 700, XKB_KEY_ccedilla);
    set_repeat(b, 35, 900);
    expect("split shared group again", 30, 700, XKB_KEY_ccedilla);
    set_repeat(a, 20, 500);
    expect("replace active group again", 20, 500, XKB_KEY_ccedilla);
    set_map(a, "us");
    expect("replace active keymap", 20, 500, XKB_KEY_semicolon);
    set_map(b, "us");
    expect("change inactive keymap", 20, 500, XKB_KEY_semicolon);
    set_map(b, "br");
    expect("restore inactive keymap", 20, 500, XKB_KEY_semicolon);
    puts("READY_REMOVE");
    fflush(stdout);
    char line[64];
    assert(fgets(line, sizeof(line), stdin));
    sync_events();
    assert(a->removed);
    expect("remove active keyboard", 35, 900, XKB_KEY_ccedilla);
    puts("PASS");
    fflush(stdout);
  }
  wl_display_disconnect(display);
  return 0;
}
