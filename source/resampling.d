module resampling;

import dplug.core.vec;

nothrow @nogc:

F[] linearInterpolate(F)(const F[] src, double srcFreq, double dstFreq)
{
    immutable ratio = srcFreq / dstFreq;
    immutable dstLength = cast(size_t) (ratio * src.length);
    auto dst = makeVec!F(dstLength);
    immutable iratio = 1.0 / ratio;
    dst[0] = src[0];
    foreach (i; 1 .. dstLength)
    {
        auto j = cast(size_t) (iratio * i);
        if (j + 1 == src.length)
        {
            dst[i .. $][] = src[j];
            break;
        }
        else
        {
            auto l = src[j];
            auto r = src[j + 1];
            auto ld = i - ratio * j;
            auto rd = ratio * (j + 1) - i;
            dst[i] = (l * rd + r * ld) / (rd + ld);
        }
    }
    return dst.releaseData();
}

@system unittest
{
    static immutable src = [1.0, 2.0, 3.0];
    auto dst = linearInterpolate(src, 2.0, 1.0);
    static immutable expect = [1.0, 1.5, 2.0, 2.5, 3.0, 3.0];
    assert(dst == expect);
}
