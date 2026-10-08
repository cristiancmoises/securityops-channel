/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <ngspice/sharedspice.h>

static int stopped;

static int output(char *message, int id, void *data) {
    (void)id;
    (void)data;
    puts(message);
    return 0;
}

static int exited(int status, bool immediate, bool quit, int id, void *data) {
    (void)status;
    (void)immediate;
    (void)quit;
    (void)id;
    (void)data;
    stopped = 1;
    return 0;
}

int main(void) {
    char *circuit[] = {"Shared API divider", "V1 in 0 10",
                       "R1 in out 1k", "R2 out 0 1k", ".end", NULL};
    if (strcmp(NGSPICE_PACKAGE_VERSION, "47") != 0 ||
        ngSpice_Init(output, NULL, exited, NULL, NULL, NULL, NULL) != 0 ||
        ngSpice_Circ(circuit) != 0 || ngSpice_Command("op") != 0 || stopped) {
        fputs("Shared API initialization or operating point failed\n", stderr);
        return 1;
    }
    pvector_info voltage = ngGet_Vec_Info("v(out)");
    if (!voltage || voltage->v_length != 1 || !voltage->v_realdata ||
        !isfinite(voltage->v_realdata[0]) ||
        fabs(voltage->v_realdata[0] - 5.0) > 1e-9) {
        fputs("Shared API returned an invalid divider voltage\n", stderr);
        return 1;
    }
    puts("SECURITYOPS_SHARED_PASS");
    return 0;
}
