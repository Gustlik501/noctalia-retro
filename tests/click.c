#include <wayland-client.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include "pointer.h"
static struct zwlr_virtual_pointer_manager_v1 *manager;
static void global(void *data, struct wl_registry *r, uint32_t name, const char *iface, uint32_t version) {
  if (!strcmp(iface, "zwlr_virtual_pointer_manager_v1"))
    manager = wl_registry_bind(r, name, &zwlr_virtual_pointer_manager_v1_interface, version > 2 ? 2 : version);
}
static void removed(void *data, struct wl_registry *r, uint32_t name) {}
static const struct wl_registry_listener listener = {global, removed};
int main(int argc, char **argv) {
  if (argc != 3) return 2;
  struct wl_display *d = wl_display_connect(NULL);
  if (!d) return 3;
  struct wl_registry *r = wl_display_get_registry(d);
  wl_registry_add_listener(r, &listener, NULL);
  wl_display_roundtrip(d);
  if (!manager) return 4;
  struct zwlr_virtual_pointer_v1 *p = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager, NULL);
  wl_display_roundtrip(d);
  zwlr_virtual_pointer_v1_motion_absolute(p, 1, atoi(argv[1]), atoi(argv[2]), 1920, 1080);
  zwlr_virtual_pointer_v1_frame(p);
  wl_display_roundtrip(d); usleep(150000);
  zwlr_virtual_pointer_v1_button(p, 2, 272, 1); zwlr_virtual_pointer_v1_frame(p);
  wl_display_roundtrip(d); usleep(100000);
  zwlr_virtual_pointer_v1_button(p, 3, 272, 0); zwlr_virtual_pointer_v1_frame(p);
  wl_display_roundtrip(d); usleep(100000);
  zwlr_virtual_pointer_v1_destroy(p);
  zwlr_virtual_pointer_manager_v1_destroy(manager);
  wl_registry_destroy(r); wl_display_disconnect(d);
  return 0;
}
