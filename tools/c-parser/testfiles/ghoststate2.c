/*
 * Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

int f(int x)
{
  /** GHOSTUPD:
        "(True, (%n. n + 1))" */
  return x + 3;
}
