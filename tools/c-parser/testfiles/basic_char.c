/*
 * Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

int f (int i)
{
  return i + 1;
}

int g(char c)
{
  return f(c + 3);
}
