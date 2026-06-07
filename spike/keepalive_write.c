// Minimal faithful version of DriveCaffeine's WRITE keep-alive pattern.
// Writes a tiny fixed payload at offset 0, then forces a flush all the way
// to physical media with F_FULLFSYNC (plain fsync/sync is NOT enough on macOS
// — it can return while the data still sits in the drive's own cache).
//
// Build:  cc -O2 -o keepalive_write keepalive_write.c
// Usage:  ./keepalive_write /Volumes/YourDrive/.drivecaffeine_keepalive
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s <path>\n", argv[0]); return 2; }
    int fd = open(argv[1], O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) { perror("open"); return 1; }          // e.g. EROFS on read-only volume
    char buf[8] = {0};                                  // fixed size — file never grows
    if (write(fd, buf, sizeof buf) < 0) { perror("write"); close(fd); return 1; }
    if (fcntl(fd, F_FULLFSYNC) < 0) { perror("F_FULLFSYNC"); close(fd); return 1; }
    close(fd);
    return 0;
}
