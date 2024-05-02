
  double out_val = 0.0;

  for (int32_t iA = A1_pos[0]; iA < A1_pos[1]; iA++) {
    for (int32_t jB = B1_pos[0]; jB < B1_pos[1]; jB++) {
      int32_t kA = A2_pos[iA];
      int32_t pA2_end = A2_pos[(iA + 1)];
      int32_t kB = B2_pos[jB];
      int32_t pB2_end = B2_pos[(jB + 1)];

      while (kA < pA2_end && kB < pB2_end) {
        int32_t kA0 = A2_crd[kA];
        int32_t kB0 = B2_crd[kB];
        int32_t k = TACO_MIN(kA0,kB0);
        if (kA0 == k && kB0 == k) {
          out_val += A_vals[kA] * B_vals[kB];
        }
        kA += (int32_t)(kA0 == k);
        kB += (int32_t)(kB0 == k);
      }
    }
  }

  return out_val;

