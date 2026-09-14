#ifndef GNE_SIGNAL_H
#define GNE_SIGNAL_H

#ifdef __cplusplus
extern "C" {
#endif

void gne_install(const char *crash_file_path, const char *platform);
void gne_crash_native(void);
const char *gne_crash_file_path(void);

#ifdef __cplusplus
}
#endif

#endif
