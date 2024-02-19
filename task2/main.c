#include "util.h"

#define SYS_EXIT 1
#define SYS_READ 3
#define SYS_WRITE 4
#define SYS_OPEN 5
#define SYS_CLOSE 6

extern int system_call(int syscall_number, ...);
extern void infector(char*);

void printFileContent(const char *filename) {
    int fd = system_call(SYS_OPEN, filename, 0);
    if (fd < 0) {
        system_call(SYS_EXIT, 0x55);
    }

    char buffer[8192];
    int bytesRead;

    while ((bytesRead = system_call(SYS_READ, fd, buffer, sizeof(buffer))) > 0) {
        system_call(SYS_WRITE, 1, buffer, bytesRead);
    }

    if (bytesRead < 0) {
        system_call(SYS_CLOSE, fd);
        system_call(SYS_EXIT, 0x55);
    }

    system_call(SYS_CLOSE, fd);
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        system_call(SYS_EXIT, 0x55);
    }

    if (strncmp(argv[1], "-a", 2) == 0 && argc == 2) {
        infector(argv[1]+2);
        system_call(SYS_WRITE, 1, "VIRUS ATTACHED\n", 15);
    } else {
        printFileContent(argv[1]);
    }

    return 0;
}
