using UnityEngine;

public class OneEuro
{
    public float minCutoff;
    public float beta;
    public float dCutoff = 1f;

    bool initialized;
    float xPrev;
    float dxPrev;
    float tPrev;

    public OneEuro(float minCutoff, float beta)
    {
        this.minCutoff = minCutoff;
        this.beta = beta;
    }

    public void Reset()
    {
        initialized = false;
    }

    static float Alpha(float cutoff, float dt)
    {
        float tau = 1f / (2f * Mathf.PI * Mathf.Max(cutoff, 1e-4f));
        return 1f / (1f + tau / dt);
    }

    public float Filter(float x, float t)
    {
        if (!initialized)
        {
            initialized = true;
            xPrev = x;
            dxPrev = 0f;
            tPrev = t;
            return x;
        }

        float dt = Mathf.Max(t - tPrev, 1e-4f);
        tPrev = t;

        float dx = (x - xPrev) / dt;
        float edx = Mathf.Lerp(dxPrev, dx, Alpha(dCutoff, dt));
        float cutoff = minCutoff + beta * Mathf.Abs(edx);
        float xHat = Mathf.Lerp(xPrev, x, Alpha(cutoff, dt));

        xPrev = xHat;
        dxPrev = edx;
        return xHat;
    }
}

public class OneEuroVec3
{
    public float minCutoff;
    public float beta;

    readonly OneEuro fx;
    readonly OneEuro fy;
    readonly OneEuro fz;

    public OneEuroVec3(float minCutoff, float beta)
    {
        this.minCutoff = minCutoff;
        this.beta = beta;
        fx = new OneEuro(minCutoff, beta);
        fy = new OneEuro(minCutoff, beta);
        fz = new OneEuro(minCutoff, beta);
    }

    public void Reset()
    {
        fx.Reset();
        fy.Reset();
        fz.Reset();
    }

    public Vector3 Filter(Vector3 v, float t)
    {
        fx.minCutoff = minCutoff; fx.beta = beta;
        fy.minCutoff = minCutoff; fy.beta = beta;
        fz.minCutoff = minCutoff; fz.beta = beta;
        return new Vector3(fx.Filter(v.x, t), fy.Filter(v.y, t), fz.Filter(v.z, t));
    }
}