(define-private (airdrop (id uint))
  (match (contract-call? .megapont-space-agency-v2-minter airdrop id)
    success 1
    failure 0))


(map airdrop
(list
u3001
u3002
u3003
u3004
u3005
u3006
u3007
u3008
u3009
u3010
u3011
u3012
u3013
u3014
u3015
u3016
u3017
u3018
u3019
u3020
u3021
u3022
u3023
u3024
u3025
u3026
u3027
u3028
u3029
u3030
u3031
u3032
u3033
u3034
u3035
u3036
u3037
u3038
u3039
u3040
u3041
u3042
u3043
u3044
u3045
u3046
u3047
u3048
u3049
u3050
u3051
u3052
u3053
u3054
u3055
u3056
u3057
u3058
u3059
u3060
u3061
u3062
u3063
u3064
u3065
u3066
u3067
u3068
u3069
u3070
u3071
u3072
u3073
u3074
u3075
u3076
u3077
u3078
u3079
u3080
u3081
u3082
u3083
u3084
u3085
u3086
u3087
u3088
u3089
u3090
u3091
u3092
u3093
u3094
u3095
u3096
u3097
u3098
u3099
u3100
u3101
u3102
u3103
u3104
u3105
u3106
u3107
u3108
u3109
u3110
u3111
u3112
u3113
u3114
u3115
u3116
u3117
u3118
u3119
u3120
u3121
u3122
u3123
u3124
u3125
u3126
u3127
u3128
u3129
u3130
u3131
u3132
u3133
u3134
u3135
u3136
u3137
u3138
u3139
u3140
u3141
u3142
u3143
u3144
u3145
u3146
u3147
u3148
u3149
u3150
u3151
u3152
u3153
u3154
u3155
u3156
u3157
u3158
u3159
u3160
u3161
u3162
u3163
u3164
u3165
u3166
u3167
u3168
u3169
u3170
u3171
u3172
u3173
u3174
u3175
u3176
u3177
u3178
u3179
u3180
u3181
u3182
u3183
u3184
u3185
u3186
u3187
u3188
u3189
u3190
u3191
u3192
u3193
u3194
u3195
u3196
u3197
u3198
u3199
u3200
u3201
u3202
u3203
u3204
u3205
u3206
u3207
u3208
u3209
u3210
u3211
u3212
u3213
u3214
u3215
u3216
u3217
u3218
u3219
u3220
u3221
u3222
u3223
u3224
u3225
u3226
u3227
u3228
u3229
u3230
u3231
u3232
u3233
u3234
u3235
u3236
u3237
u3238
u3239
u3240
u3241
u3242
u3243
u3244
u3245
u3246
u3247
u3248
u3249
u3250
u3251
u3252
u3253
u3254
u3255
u3256
u3257
u3258
u3259
u3260
u3261
u3262
u3263
u3264
u3265
u3266
u3267
u3268
u3269
u3270
u3271
u3272
u3273
u3274
u3275
u3276
u3277
u3278
u3279
u3280
u3281
u3282
u3283
u3284
u3285
u3286
u3287
u3288
u3289
u3290
u3291
u3292
u3293
u3294
u3295
u3296
u3297
u3298
u3299
u3300
u3301
u3302
u3303
u3304
u3305
u3306
u3307
u3308
u3309
u3310
u3311
u3312
u3313
u3314
u3315
u3316
u3317
u3318
u3319
u3320
u3321
u3322
u3323
u3324
u3325
u3326
u3327
u3328
u3329
u3330
u3331
u3332
u3333
u3334
u3335
u3336
u3337
u3338
u3339
u3340
u3341
u3342
u3343
u3344
u3345
u3346
u3347
u3348
u3349
u3350
u3351
u3352
u3353
u3354
u3355
u3356
u3357
u3358
u3359
u3360
u3361
u3362
u3363
u3364
u3365
u3366
u3367
u3368
u3369
u3370
u3371
u3372
u3373
u3374
u3375
u3376
u3377
u3378
u3379
u3380
u3381
u3382
u3383
u3384
u3385
u3386
u3387
u3388
u3389
u3390
u3391
u3392
u3393
u3394
u3395
u3396
u3397
u3398
u3399
u3400
u3401
u3402
u3403
u3404
u3405
u3406
u3407
u3408
u3409
u3410
u3411
u3412
u3413
u3414
u3415
u3416
u3417
u3418
u3419
u3420
u3421
u3422
u3423
u3424
u3425
u3426
u3427
u3428
u3429
u3430
u3431
u3432
u3433
u3434
u3435
u3436
u3437
u3438
u3439
u3440
u3441
u3442
u3443
u3444
u3445
u3446
u3447
u3448
u3449
u3450
u3451
u3452
u3453
u3454
u3455
u3456
u3457
u3458
u3459
u3460
u3461
u3462
u3463
u3464
u3465
u3466
u3467
u3468
u3469
u3470
u3471
u3472
u3473
u3474
u3475
u3476
u3477
u3478
u3479
u3480
u3481
u3482
u3483
u3484
u3485
u3486
u3487
u3488
u3489
u3490
u3491
u3492
u3493
u3494
u3495
u3496
u3497
u3498
u3499
u3500
))
