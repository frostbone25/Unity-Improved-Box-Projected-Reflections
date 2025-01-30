# Improved Box Projected Reflections
A work-in-progress attempt at improving Box Projected Reflections.

## Contact Hardening

#### Contact Hardening: None
![1](GithubContent/1.png)

The issue with how box-projected reflections are typically done is that when sampled, the roughness of the reflection is consistent regardless of camera position, and object position. This is not the case when you compare it to a proper path traced/ground truth result.

With that there are a couple of implementations here that attempt to alleviate that problem and make them more true to life and higher fidelity.

#### Contact Hardening: Approximated
![2](GithubContent/2.png)

This is done by modifying Unity's existing box projection method to output a hit distance from the bounds of the box, to where the object is. Using the hit distance to offset the mip level when sampling the cubemap to be sharper when closer to the bounds of the probe, and rougher when farther from the bounds. It's very cheap and fast, though not accurate as it fails to model anisotropic reflections.

Despite that, this alleviates a couple of visual problems we saw before. 
1. This attempts to solve the problem of reflections being too consistent, and making them irregular as they would be in a proper path traced result. *(I.e the closer to the actual source of the reflection bounds, the sharper the reflection gets)*
2. In some situations *(particularly the one illustrated here)* it actually contributes to improved specular occlusion. Since the contact hardening reflections reveal the underlying cubemap more, there is less of a glowing appearance in the corners of the bounds. *(Note that this is assuming your reflection probe is placed and configured well to approximate the geometry of the space/room)*

NOTE: The approximation is mostly arbitrarily tweaked by hand with random values until it looks right. I would like to see an improvement here that is more mathematically correct and plausible *(versus my initial banging random rocks together until we stumble upon something decent)*. In addition, any possible tricks to help with mimicking anisotropic reflections would get this to match the path-traced result more closely would be more ideal. 

However despite that, in most circumstances, this is a marginal improvement over the classic method.

#### Contact Hardening: Traced
![3](GithubContent/3.png)

This is a more accurate way of handling reflections. Using multiple randomized samples, and GGX to model roughness. It can also model anisotropic specular reflections more accurately.

The cons however is that it's also expensive at high sample counts. More work to be done here such as...
1. Use blue noise *(or another noise pattern that lends itself better to filtering or better perceptual quality)*.
2. Importance sampling *(better ray allocation at low sample counts for improved quality)*

## Beveled Box Projection

#### Beveled Box Projection: Off
![13](GithubContent/13.png)

Classic box projection, it's fast but has sharp edges and can look jarring especially when the cubemap is sampled at a higher mip level.

#### Beveled Box Projection: On
![14](GithubContent/14.png)

Using a beveled box projection with an adjustable bevel factor, to smooth out the sharp edges you'd get with the classic method.

The initial idea here is 
1. Give an artist-controlled parameter to smooth out the reflection probe projection.
2. A more complex but optically inspired approach by mapping the bevel factor to increased roughness, so the blurrier the reflection gets, the smoother the edges of the box projection are.

Granted the current implementation has artifacts at high bevel values, and also has higher instruction count/math complexity with a beveled box projection. **In my opinion**: For most circumstances this is not as transformative as contact hardening, which already visually "un-boxes" the appearance of your box projected reflection for a much cheaper cost.

### TODO/Ideas:

- Approximated: A more mathematically/optically plausible function for contact hardening.
- Traced: Use Blue Noise for better perceptual quality.
- Traced: Importance Sampling *(by using the already provided mips to reduce required samples/noise. Could also use the luminance of the cubemap for importance sampling)*
- Traced: Animated noise.
- Quad Intrinsics?

## Results

*No Contact Hardening*
![4](GithubContent/4.png)

*Approximated Contact Hardening*
![5](GithubContent/5.png)

*Traced Contact Hardening*
![6](GithubContent/6.png)

*Normal Maps with No Contact Hardening*
![7](GithubContent/7.png)

*Normal Maps with Approximated Contact Hardening*
![8](GithubContent/8.png)

*Normal Maps with Traced Contact Hardening*
![9](GithubContent/9.png)

*No Contact Hardening*
![10](GithubContent/10.png)

*Approximated Contact Hardening*
![11](GithubContent/11.png)

*Traced Contact Hardening*
![12](GithubContent/12.png)
