import { z } from 'zod';

export const GoogleLoginSchema = z.object({
  idToken: z.string().min(1, 'Google idToken is required'),
});

export const RefreshTokenSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token is required'),
});

export const OnboardingSchema = z.object({
  firstName: z
    .string()
    .trim()
    .min(1, 'First name is mandatory and cannot be empty')
    .max(50, 'First name cannot exceed 50 characters'),
  lastName: z
    .string()
    .trim()
    .min(1, 'Second/last name is mandatory and cannot be empty')
    .max(50, 'Second/last name cannot exceed 50 characters'),
  dob: z
    .string()
    .refine((val) => !isNaN(Date.parse(val)), {
      message: 'Date of birth must be a valid ISO date string',
    })
    .refine(
      (val) => {
        const birthDate = new Date(val);
        const now = new Date();
        const minAgeDate = new Date(now.getFullYear() - 4, now.getMonth(), now.getDate());
        const maxAgeDate = new Date(now.getFullYear() - 120, now.getMonth(), now.getDate());
        return birthDate <= minAgeDate && birthDate >= maxAgeDate;
      },
      {
        message: 'You must be at least 4 years old and provide a valid past date of birth',
      }
    ),
  gender: z
    .enum(['Male', 'Female', 'Non-Binary', 'Prefer not to say'], {
      errorMap: () => ({
        message: 'Gender is mandatory. Select Male, Female, Non-Binary, or Prefer not to say',
      }),
    }),
  religion: z
    .string()
    .trim()
    .min(1, 'Religion / belief preference is mandatory')
    .max(80, 'Religion description cannot exceed 80 characters'),
  country: z
    .string()
    .trim()
    .min(1, 'Country is mandatory')
    .max(80, 'Country cannot exceed 80 characters'),
  avatarUrl: z.string().url().optional().or(z.literal('')),
});

export type OnboardingInput = z.infer<typeof OnboardingSchema>;
