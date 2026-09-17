/* SPDX-License-Identifier: BSD-3-Clause
 * Copyright (c) 2026 SecurityOps contributors
 * Run only through layer-surface-smoke.py on its private compositor. */
#define _POSIX_C_SOURCE 200809L
#include "wlr-layer-shell-client-protocol.h"
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>

static struct wl_display *display;
static struct wl_compositor *compositor;
static struct wl_shm *shm;
static struct wl_output *output;
static struct zwlr_layer_shell_v1 *shell;
struct surface {
    struct wl_surface *wl;
    struct zwlr_layer_surface_v1 *layer;
    unsigned configures, width, height;
};

static void configured(void *data, struct zwlr_layer_surface_v1 *layer,
                       uint32_t serial, uint32_t width, uint32_t height) {
    struct surface *surface = data;
    surface->configures++;
    surface->width = width;
    surface->height = height;
    zwlr_layer_surface_v1_ack_configure(layer, serial);
}
static void closed(void *data, struct zwlr_layer_surface_v1 *layer) {
    (void)data;
    (void)layer;
    assert(!"unexpected layer_surface closed");
}
static const struct zwlr_layer_surface_v1_listener listener = {
    configured, closed
};
static void global(void *data, struct wl_registry *registry, uint32_t name,
                   const char *interface, uint32_t version) {
    (void)data;
    (void)version;
    if (!strcmp(interface, "wl_compositor"))
        compositor = wl_registry_bind(registry, name, &wl_compositor_interface, 4);
    else if (!strcmp(interface, "wl_shm"))
        shm = wl_registry_bind(registry, name, &wl_shm_interface, 1);
    else if (!strcmp(interface, "wl_output") && !output)
        output = wl_registry_bind(registry, name, &wl_output_interface, 1);
    else if (!strcmp(interface, "zwlr_layer_shell_v1"))
        shell = wl_registry_bind(registry, name, &zwlr_layer_shell_v1_interface, 4);
}
static void removed(void *data, struct wl_registry *registry, uint32_t name) {
    (void)data;
    (void)registry;
    (void)name;
}
static const struct wl_registry_listener registry_listener = {global, removed};
static void sync_events(void) {
    for (int i = 0; i < 4; i++)
        assert(wl_display_roundtrip(display) >= 0);
}
static void wait_size(struct surface *surface, unsigned before,
                      unsigned width, unsigned height) {
    struct timespec pause = {0, 10000000};
    for (int i = 0; i < 100; i++) {
        sync_events();
        if (surface->configures > before && surface->width == width &&
            surface->height == height)
            return;
        nanosleep(&pause, NULL);
    }
    fprintf(stderr, "wanted new configure %ux%u; count %u -> %u, size %ux%u\n",
            width, height, before, surface->configures,
            surface->width, surface->height);
    assert(!"missing layer configure");
}
static void create(struct surface *surface, const char *name,
                   unsigned width, unsigned height, unsigned anchor,
                   int exclusive) {
    *surface = (struct surface){0};
    surface->wl = wl_compositor_create_surface(compositor);
    surface->layer = zwlr_layer_shell_v1_get_layer_surface(
        shell, surface->wl, output, ZWLR_LAYER_SHELL_V1_LAYER_TOP, name);
    zwlr_layer_surface_v1_add_listener(surface->layer, &listener, surface);
    zwlr_layer_surface_v1_set_size(surface->layer, width, height);
    zwlr_layer_surface_v1_set_anchor(surface->layer, anchor);
    zwlr_layer_surface_v1_set_exclusive_zone(surface->layer, exclusive);
    wl_surface_commit(surface->wl);
}
static void map_surface(struct surface *surface) {
    assert(surface->width && surface->height);
    size_t size = (size_t)surface->width * surface->height * 4;
    const char *runtime = getenv("XDG_RUNTIME_DIR");
    char path[1024];
    assert(snprintf(path, sizeof path, "%s/layer-buffer-XXXXXX", runtime) > 0);
    int fd = mkstemp(path);
    assert(fd >= 0);
    assert(unlink(path) == 0 && ftruncate(fd, (off_t)size) == 0);
    uint32_t *pixels = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    assert(pixels != MAP_FAILED);
    for (size_t i = 0; i < size / 4; i++)
        pixels[i] = 0xff123456;
    struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, (int32_t)size);
    struct wl_buffer *buffer = wl_shm_pool_create_buffer(
        pool, 0, (int32_t)surface->width, (int32_t)surface->height,
        (int32_t)surface->width * 4, WL_SHM_FORMAT_XRGB8888);
    wl_shm_pool_destroy(pool);
    close(fd);
    munmap(pixels, size);
    wl_surface_attach(surface->wl, buffer, 0, 0);
    wl_surface_damage_buffer(surface->wl, 0, 0, INT32_MAX, INT32_MAX);
    wl_surface_commit(surface->wl);
    sync_events();
    wl_buffer_destroy(buffer);
}
static void destroy(struct surface *surface) {
    zwlr_layer_surface_v1_destroy(surface->layer);
    wl_surface_destroy(surface->wl);
    sync_events();
}

int main(void) {
    assert(getenv("RIVER_PRIVATE_LAYER_TEST"));
    setbuf(stdout, NULL);
    display = wl_display_connect(NULL);
    assert(display);
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    sync_events();
    assert(compositor && shm && output && shell);
    const unsigned top = ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP;
    const unsigned right = ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT;
    const unsigned left = ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT;
    const unsigned bottom = ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM;
    struct surface notification, fill, bar, trigger;
    create(&notification, "pre-buffer-resize", 320, 62, top | right, 0);
    wait_size(&notification, 0, 320, 62);
    unsigned before = notification.configures;
    zwlr_layer_surface_v1_set_size(notification.layer, 320, 81);
    wl_surface_commit(notification.wl);
    wait_size(&notification, before, 320, 81);
    puts("PASS resize before first buffer");
    map_surface(&notification);
    before = notification.configures;
    wl_surface_attach(notification.wl, NULL, 0, 0);
    wl_surface_commit(notification.wl);
    sync_events();
    assert(notification.configures == before);
    puts("PASS detach without unsolicited configure");
    zwlr_layer_surface_v1_set_size(notification.layer, 320, 92);
    wl_surface_commit(notification.wl);
    wait_size(&notification, before, 320, 92);
    before = notification.configures;
    zwlr_layer_surface_v1_set_size(notification.layer, 320, 103);
    wl_surface_commit(notification.wl);
    wait_size(&notification, before, 320, 103);
    map_surface(&notification);
    puts("PASS remap and resize before remap buffer");
    destroy(&notification);
    create(&fill, "workarea-observer", 0, 0, top | right | bottom | left, 0);
    sync_events();
    assert(fill.width && fill.height);
    unsigned full_width = fill.width, full_height = fill.height;
    map_surface(&fill);
    before = fill.configures;
    create(&bar, "exclusive-bar", 0, 40, top | right | left, 40);
    wait_size(&bar, 0, full_width, 40);
    map_surface(&bar);
    wait_size(&fill, before, full_width, full_height - 40);
    map_surface(&fill);
    before = fill.configures;
    unsigned bar_before = bar.configures;
    wl_surface_attach(bar.wl, NULL, 0, 0);
    wl_surface_commit(bar.wl);
    wait_size(&fill, before, full_width, full_height);
    map_surface(&fill);
    create(&trigger, "arrange-after-unmap", 100, 100, bottom | right, 0);
    wait_size(&trigger, 0, 100, 100);
    assert(bar.configures == bar_before && fill.height == full_height);
    destroy(&trigger);
    puts("PASS exclusive unmap clears reservation across later arrange");
    before = fill.configures;
    wl_surface_commit(bar.wl);
    wait_size(&bar, bar_before, full_width, 40);
    map_surface(&bar);
    wait_size(&fill, before, full_width, full_height - 40);
    map_surface(&fill);
    before = fill.configures;
    destroy(&bar);
    wait_size(&fill, before, full_width, full_height);
    map_surface(&fill);
    puts("PASS mapped exclusive destruction clears reservation");
    create(&bar, "never-mapped-exclusive", 0, 40, top | right | left, 40);
    wait_size(&bar, 0, full_width, 40);
    assert(fill.height == full_height);
    destroy(&bar);
    assert(fill.height == full_height);
    puts("PASS never-mapped exclusive surface never reserves area");
    destroy(&fill);
    wl_registry_destroy(registry);
    wl_display_disconnect(display);
    return 0;
}
