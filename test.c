#include <stdio.h>
#include <stdlib.h>
#include "surrender.h"

typedef uint32_t pixel;

typedef struct {
  float x;
  float y;
  float z;
} pos3;

typedef struct {
  pos3 p0;
  pos3 p1;
  pos3 p2;
  pixel color;
} tri3;

/* Netpbm PAM graphics format */
void pam_save(FILE* f, const uint32_t* image_pixels,
              int32_t width, int32_t height) {
  fprintf(f, "P7\n");
  fprintf(f, "WIDTH %d\n", width);
  fprintf(f, "HEIGHT %d\n", height);
  fprintf(f, "DEPTH 4\n");
  fprintf(f, "MAXVAL 255\n");
  fprintf(f, "TUPLTYPE RGB_ALPHA\n");
  fprintf(f, "ENDHDR\n");
  uint8_t* image = (uint8_t*) image_pixels;
  for (int32_t i = 0; i < width * height; i++) {
    uint8_t r, g, b, a;
    r = image[i * 4 + 0];
    g = image[i * 4 + 1];
    b = image[i * 4 + 2];
    a = image[i * 4 + 3];
    fputc(r, f);
    fputc(g, f);
    fputc(b, f);
    fputc(a, f);
  }
}

int32_t height = 1080;
int32_t width = 1920;
int32_t bbox_max_size = 1000;
int32_t view_dist = 600;

// Uses ABGR color format.
tri3 triangles[] = {
  { { 310, 0, 500 }, { 800, 800, 400 }, { 320, 800, 300 }, 0xff0000ff },
  { { 100, 150, 550 }, { 600, 440, 430 }, { 120, 400, 300 }, 0xffff0000 },
};
int32_t n_triangles = sizeof(triangles) / sizeof(tri3);

#define COPY(type, source, destination) \
  type *destination = (type*) malloc(sizeof(type) * n_triangles); \
  for (int i = 0; i < n_triangles; i++) destination[i] = triangles[i].source;

int main(int argc, char* argv[]) {
  COPY(float, p0.x, t_p0_xs);
  COPY(float, p0.y, t_p0_ys);
  COPY(float, p0.z, t_p0_zs);
  COPY(float, p1.x, t_p1_xs);
  COPY(float, p1.y, t_p1_ys);
  COPY(float, p1.z, t_p1_zs);
  COPY(float, p2.x, t_p2_xs);
  COPY(float, p2.y, t_p2_ys);
  COPY(float, p2.z, t_p2_zs);
  COPY(uint32_t, color, t_colors);

  struct futhark_context_config *cfg = futhark_context_config_new();
  struct futhark_context *ctx = futhark_context_new(cfg);
  struct futhark_u32_1d *out_arr = NULL;
  int ret = futhark_entry_render_triangles_raw(ctx, &out_arr, height, width, bbox_max_size, view_dist,
                                               futhark_new_f32_1d(ctx, t_p0_xs, n_triangles),
                                               futhark_new_f32_1d(ctx, t_p0_ys, n_triangles),
                                               futhark_new_f32_1d(ctx, t_p0_zs, n_triangles),
                                               futhark_new_f32_1d(ctx, t_p1_xs, n_triangles),
                                               futhark_new_f32_1d(ctx, t_p1_ys, n_triangles),
                                               futhark_new_f32_1d(ctx, t_p1_zs, n_triangles),
                                               futhark_new_f32_1d(ctx, t_p2_xs, n_triangles),
                                               futhark_new_f32_1d(ctx, t_p2_ys, n_triangles),
                                               futhark_new_f32_1d(ctx, t_p2_zs, n_triangles),
                                               futhark_new_u32_1d(ctx, t_colors, n_triangles));
  if (ret != 0) {
    puts(futhark_context_get_error(ctx));
    return EXIT_FAILURE;
  }
  uint32_t *render = (uint32_t*) malloc(sizeof(uint32_t) * height * width);
  futhark_values_u32_1d(ctx, out_arr, render);

  FILE* output_file = fopen("test.pam", "wb");
  pam_save(output_file, render, width, height);
  fclose(output_file);
  // FIXME: Do some freeing.
  return EXIT_SUCCESS;
}
