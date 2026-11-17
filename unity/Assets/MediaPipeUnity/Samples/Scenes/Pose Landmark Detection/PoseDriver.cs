using System;
using UnityEngine;

[Serializable]
public class LandmarkMsg { public float[] l; }

public class PoseDriver : MonoBehaviour
{
    public Animator animator;
    public float aspect = 0.5625f;
    public bool mirror = true;
    public float rotation;
    [Range(0f, 1f)] public float minVisibility = 0.5f;
    [Range(0.05f, 1f)] public float smoothing = 0.35f;
    [Range(0.05f, 1f)] public float worldSmoothing = 0.5f;
    public bool useWorld = true;
    public bool useOneEuro = true;
    public float minCutoff = 0.6f;
    public float beta = 4f;
    public float holdSeconds = 0.5f;
    public float returnToRestSeconds = 2f;
    public bool debugLog;

    static readonly int[] KeyIdx = { 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28 };

    readonly Vector3[] pts = new Vector3[33];
    readonly float[] vis = new float[33];
    readonly bool[] seen = new bool[33];

    readonly Vector3[] wpts = new Vector3[33];
    readonly float[] wvis = new float[33];
    readonly bool[] wseen = new bool[33];

    readonly OneEuroVec3[] imgFilters = new OneEuroVec3[33];
    readonly OneEuroVec3[] worldFilters = new OneEuroVec3[33];

    float lastMsgTime = -999f;
    float lastWorldTime = -999f;
    int msgCount;

    struct Seg
    {
        public HumanBodyBones bone, child;
        public int a, b;
        public Transform t, c;
        public Vector3 restDir;
        public Quaternion restRot;
    }
    Seg[] segs;

    Transform hips;
    Transform chest;
    Quaternion hipsRestRot;
    Quaternion chestRestRot;
    Vector3 hipsRestLine;
    Quaternion restHipFrame = Quaternion.identity;
    Quaternion restChestFrame = Quaternion.identity;

    readonly float[] pending = new float[48];
    readonly float[] applyBuf = new float[48];
    readonly float[] pendingWorld = new float[48];
    readonly float[] applyBufWorld = new float[48];
    readonly object pendingLock = new object();
    volatile bool hasPending;
    volatile bool hasPendingWorld;

    public bool TrackingOk => Time.time - Mathf.Max(lastMsgTime, lastWorldTime) < holdSeconds;

    void Awake()
    {
        if (animator == null) animator = GetComponentInChildren<Animator>();
    }

    void Start()
    {
        if (animator != null && !animator.gameObject.scene.IsValid())
        {
            Debug.LogError("PoseDriver: the Animator is a prefab asset, not a scene object. Assign the instance from the Hierarchy.");
            enabled = false;
            return;
        }

        if (animator == null || !animator.isHuman)
        {
            Debug.LogError("PoseDriver: needs an Animator with a Humanoid avatar.");
            enabled = false;
            return;
        }

        segs = new[]
        {
            Make(HumanBodyBones.LeftUpperArm,  HumanBodyBones.LeftLowerArm,  11, 13),
            Make(HumanBodyBones.LeftLowerArm,  HumanBodyBones.LeftHand,      13, 15),
            Make(HumanBodyBones.RightUpperArm, HumanBodyBones.RightLowerArm, 12, 14),
            Make(HumanBodyBones.RightLowerArm, HumanBodyBones.RightHand,     14, 16),
            Make(HumanBodyBones.LeftUpperLeg,  HumanBodyBones.LeftLowerLeg,  23, 25),
            Make(HumanBodyBones.LeftLowerLeg,  HumanBodyBones.LeftFoot,      25, 27),
            Make(HumanBodyBones.RightUpperLeg, HumanBodyBones.RightLowerLeg, 24, 26),
            Make(HumanBodyBones.RightLowerLeg, HumanBodyBones.RightFoot,     26, 28),
        };

        hips = animator.GetBoneTransform(HumanBodyBones.Hips);
        hipsRestRot = hips.rotation;

        chest = animator.GetBoneTransform(HumanBodyBones.Chest);
        if (chest == null) chest = animator.GetBoneTransform(HumanBodyBones.Spine);
        if (chest != null) chestRestRot = chest.rotation;

        Vector3 l = animator.GetBoneTransform(HumanBodyBones.LeftUpperLeg).position;
        Vector3 r = animator.GetBoneTransform(HumanBodyBones.RightUpperLeg).position;
        Vector3 ls = animator.GetBoneTransform(HumanBodyBones.LeftUpperArm).position;
        Vector3 rs = animator.GetBoneTransform(HumanBodyBones.RightUpperArm).position;

        hipsRestLine = Flat(l - r).normalized;

        Vector3 restSpine = ((ls + rs) * 0.5f - (l + r) * 0.5f).normalized;
        Vector3 restHipLine = (l - r).normalized;
        Vector3 restShoulderLine = (ls - rs).normalized;
        restHipFrame = Frame(restHipLine, restSpine);
        restChestFrame = Frame(restShoulderLine, restSpine);

        if (debugLog)
        {
            foreach (var s in segs)
                Debug.Log("PoseDriver rest " + s.bone + " dir=" + s.restDir);
        }
    }

    Seg Make(HumanBodyBones bone, HumanBodyBones child, int a, int b)
    {
        var s = new Seg { bone = bone, child = child, a = a, b = b };
        s.t = animator.GetBoneTransform(bone);
        s.c = animator.GetBoneTransform(child);
        s.restDir = (s.c.position - s.t.position).normalized;
        s.restRot = s.t.rotation;
        return s;
    }

    static Quaternion Frame(Vector3 right, Vector3 up)
    {
        Vector3 f = Vector3.Cross(right, up);
        if (f.sqrMagnitude < 1e-8f || up.sqrMagnitude < 1e-8f) return Quaternion.identity;
        return Quaternion.LookRotation(f, up);
    }

    public void OnLandmarks(string json)
    {
        LandmarkMsg m;
        try { m = JsonUtility.FromJson<LandmarkMsg>(json); }
        catch (Exception) { return; }
        if (m == null) return;
        Apply(m.l);
    }

    public void Apply(float[] l)
    {
        if (l == null || l.Length < KeyIdx.Length * 4) return;
        var m = new LandmarkMsg { l = l };

        for (int i = 0; i < KeyIdx.Length; i++)
        {
            int idx = KeyIdx[i];
            float x = m.l[i * 4], y = m.l[i * 4 + 1], z = m.l[i * 4 + 2], v = m.l[i * 4 + 3];
            vis[idx] = v;
            if (v < minVisibility) continue;

            float dx = (x - 0.5f) * aspect;
            float dy = -(y - 0.5f);
            if (Mathf.Abs(rotation) > 0.01f)
            {
                float rr = rotation * Mathf.Deg2Rad;
                float cc = Mathf.Cos(rr), ss = Mathf.Sin(rr);
                float rx = dx * cc - dy * ss;
                float ry = dx * ss + dy * cc;
                dx = rx;
                dy = ry;
            }
            float wx = mirror ? dx : -dx;
            Vector3 p = new Vector3(wx, dy, -z * aspect);

            pts[idx] = useOneEuro ? FilterPoint(imgFilters, idx, p) : (seen[idx] ? Vector3.Lerp(pts[idx], p, smoothing) : p);
            seen[idx] = true;
        }
        lastMsgTime = Time.time;

        if (debugLog && (msgCount++ % 30) == 0)
        {
            Debug.Log("PoseDriver msg: lShoulder=(" + m.l[0] + "," + m.l[1] + ") lWrist=(" +
                      m.l[16] + "," + m.l[17] + ") vis=" + m.l[19] + " mirror=" + mirror + " aspect=" + aspect);
        }
    }

    public void ApplyWorld(float[] l)
    {
        if (l == null || l.Length < KeyIdx.Length * 4) return;

        for (int i = 0; i < KeyIdx.Length; i++)
        {
            int idx = KeyIdx[i];
            float x = l[i * 4], y = l[i * 4 + 1], z = l[i * 4 + 2], v = l[i * 4 + 3];
            wvis[idx] = v;
            if (v < minVisibility) continue;

            float dx = x;
            float dy = -y;
            if (Mathf.Abs(rotation) > 0.01f)
            {
                float rr = rotation * Mathf.Deg2Rad;
                float cc = Mathf.Cos(rr), ss = Mathf.Sin(rr);
                float rx = dx * cc - dy * ss;
                float ry = dx * ss + dy * cc;
                dx = rx;
                dy = ry;
            }
            float wx = mirror ? dx : -dx;
            Vector3 p = new Vector3(wx, dy, -z);

            wpts[idx] = useOneEuro ? FilterPoint(worldFilters, idx, p) : (wseen[idx] ? Vector3.Lerp(wpts[idx], p, worldSmoothing) : p);
            wseen[idx] = true;
        }
        lastWorldTime = Time.time;
    }

    public bool WorldFresh => Time.time - lastWorldTime < holdSeconds;

    public bool TryGetWorld(int idx, float minVis, out Vector3 p)
    {
        p = default;
        if (!wseen[idx] || wvis[idx] < minVis || !WorldFresh) return false;
        p = wpts[idx];
        return true;
    }

    Vector3 FilterPoint(OneEuroVec3[] filters, int idx, Vector3 p)
    {
        if (filters[idx] == null) filters[idx] = new OneEuroVec3(minCutoff, beta);
        filters[idx].minCutoff = minCutoff;
        filters[idx].beta = beta;
        return filters[idx].Filter(p, Time.time);
    }

    public bool TryGetUV(int idx, out Vector2 uv)
    {
        uv = default;
        if (!seen[idx] || vis[idx] < minVisibility) return false;
        float dx = mirror ? pts[idx].x : -pts[idx].x;
        float dy = pts[idx].y;
        float r = -rotation * Mathf.Deg2Rad;
        float c = Mathf.Cos(r), s = Mathf.Sin(r);
        float ux = dx * c - dy * s;
        float uy = dx * s + dy * c;
        uv.x = 0.5f + ux / aspect;
        uv.y = 0.5f - uy;
        return true;
    }

    public void Push(float[] l)
    {
        if (l == null || l.Length < KeyIdx.Length * 4) return;
        lock (pendingLock)
        {
            Array.Copy(l, pending, KeyIdx.Length * 4);
            hasPending = true;
        }
    }

    public void PushWorld(float[] l)
    {
        if (l == null || l.Length < KeyIdx.Length * 4) return;
        lock (pendingLock)
        {
            Array.Copy(l, pendingWorld, KeyIdx.Length * 4);
            hasPendingWorld = true;
        }
    }

    public void SetMirror(string v) { mirror = (v == "true"); }

    public void SetAspect(string v)
    {
        if (float.TryParse(v, System.Globalization.NumberStyles.Float,
                           System.Globalization.CultureInfo.InvariantCulture, out var a) && a > 0.1f)
            aspect = a;
    }

    [ContextMenu("Test T-Pose")]
    void TestTPose()
    {
        float[] t = {
            0.60f,0.30f,0,1,  0.40f,0.30f,0,1,
            0.72f,0.30f,0,1,  0.28f,0.30f,0,1,
            0.84f,0.30f,0,1,  0.16f,0.30f,0,1,
            0.55f,0.55f,0,1,  0.45f,0.55f,0,1,
            0.55f,0.72f,0,1,  0.45f,0.72f,0,1,
            0.55f,0.90f,0,1,  0.45f,0.90f,0,1,
        };
        OnLandmarks(JsonUtility.ToJson(new LandmarkMsg { l = t }));
    }

    [ContextMenu("Test Arms Up")]
    void TestArmsUp()
    {
        float[] t = {
            0.60f,0.30f,0,1,  0.40f,0.30f,0,1,
            0.66f,0.17f,0,1,  0.34f,0.17f,0,1,
            0.70f,0.05f,0,1,  0.30f,0.05f,0,1,
            0.55f,0.55f,0,1,  0.45f,0.55f,0,1,
            0.55f,0.72f,0,1,  0.45f,0.72f,0,1,
            0.55f,0.90f,0,1,  0.45f,0.90f,0,1,
        };
        OnLandmarks(JsonUtility.ToJson(new LandmarkMsg { l = t }));
    }

    [ContextMenu("Test World Arms Forward")]
    void TestWorldArmsForward()
    {
        float[] t = {
            0.20f,-0.40f,0.00f,1,  -0.20f,-0.40f,0.00f,1,
            0.25f,-0.40f,-0.25f,1, -0.25f,-0.40f,-0.25f,1,
            0.25f,-0.40f,-0.55f,1, -0.25f,-0.40f,-0.55f,1,
            0.10f,0.00f,0.00f,1,   -0.10f,0.00f,0.00f,1,
            0.10f,0.45f,0.00f,1,   -0.10f,0.45f,0.00f,1,
            0.10f,0.90f,0.00f,1,   -0.10f,0.90f,0.00f,1,
        };
        ApplyWorld(t);
    }

    [ContextMenu("Test World T-Pose")]
    void TestWorldTPose()
    {
        float[] t = {
            0.20f,-0.40f,0,1,  -0.20f,-0.40f,0,1,
            0.45f,-0.40f,0,1, -0.45f,-0.40f,0,1,
            0.70f,-0.40f,0,1, -0.70f,-0.40f,0,1,
            0.10f,0.00f,0,1,  -0.10f,0.00f,0,1,
            0.10f,0.45f,0,1,  -0.10f,0.45f,0,1,
            0.10f,0.90f,0,1,  -0.10f,0.90f,0,1,
        };
        ApplyWorld(t);
    }

    [ContextMenu("Reset Pose")]
    void ResetPose()
    {
        if (segs == null) return;
        RelaxToRest(1f);
        lastMsgTime = -999f;
        lastWorldTime = -999f;
        Array.Clear(seen, 0, seen.Length);
        Array.Clear(wseen, 0, wseen.Length);
    }

    int Src(int leftLabelled) => mirror ? (leftLabelled % 2 == 1 ? leftLabelled + 1 : leftLabelled - 1) : leftLabelled;

    static Vector3 Flat(Vector3 v) { v.y = 0; return v; }

    bool Ok(bool[] s, float[] v, int idx) => s[idx] && v[idx] >= minVisibility;

    void RelaxToRest(float t)
    {
        hips.rotation = Quaternion.Slerp(hips.rotation, hipsRestRot, t);
        if (chest != null) chest.rotation = Quaternion.Slerp(chest.rotation, chestRestRot, t);
        for (int i = 0; i < segs.Length; i++)
            segs[i].t.rotation = Quaternion.Slerp(segs[i].t.rotation, segs[i].restRot, t);
    }

    void DriveTorso(bool useW, Vector3[] P, bool[] S, float[] V)
    {
        int hl = Src(23), hr = Src(24), sl = Src(11), sr = Src(12);
        if (!Ok(S, V, hl) || !Ok(S, V, hr)) return;

        if (useW && Ok(S, V, sl) && Ok(S, V, sr))
        {
            Vector3 hipLine = P[hl] - P[hr];
            Vector3 shoulderLine = P[sl] - P[sr];
            Vector3 spine = (P[sl] + P[sr]) * 0.5f - (P[hl] + P[hr]) * 0.5f;
            if (hipLine.sqrMagnitude < 1e-6f || shoulderLine.sqrMagnitude < 1e-6f || spine.sqrMagnitude < 1e-6f) return;

            hipLine.Normalize();
            shoulderLine.Normalize();
            spine.Normalize();

            Quaternion hipTarget = Frame(hipLine, spine) * Quaternion.Inverse(restHipFrame) * hipsRestRot;
            hips.rotation = Quaternion.Slerp(hips.rotation, hipTarget, 0.5f);

            if (chest != null)
            {
                Quaternion chestTarget = Frame(shoulderLine, spine) * Quaternion.Inverse(restChestFrame) * chestRestRot;
                chest.rotation = Quaternion.Slerp(chest.rotation, chestTarget, 0.5f);
            }
            return;
        }

        Vector3 line = Flat(P[hl] - P[hr]);
        if (line.sqrMagnitude > 1e-6f)
        {
            var target = Quaternion.FromToRotation(hipsRestLine, line.normalized) * hipsRestRot;
            hips.rotation = Quaternion.Slerp(hips.rotation, target, 0.5f);
        }
    }

    void LateUpdate()
    {
        if (segs == null) return;

        if (hasPending)
        {
            lock (pendingLock)
            {
                Array.Copy(pending, applyBuf, KeyIdx.Length * 4);
                hasPending = false;
            }
            Apply(applyBuf);
        }

        if (hasPendingWorld)
        {
            lock (pendingLock)
            {
                Array.Copy(pendingWorld, applyBufWorld, KeyIdx.Length * 4);
                hasPendingWorld = false;
            }
            ApplyWorld(applyBufWorld);
        }

        float idle = Time.time - Mathf.Max(lastMsgTime, lastWorldTime);
        if (idle > returnToRestSeconds)
        {
            RelaxToRest(0.1f);
            return;
        }
        if (idle > holdSeconds) return;

        bool useW = useWorld && Time.time - lastWorldTime < holdSeconds;
        Vector3[] P = useW ? wpts : pts;
        bool[] S = useW ? wseen : seen;
        float[] V = useW ? wvis : vis;

        DriveTorso(useW, P, S, V);

        for (int i = 0; i < segs.Length; i++)
        {
            var s = segs[i];
            int a = Src(s.a), b = Src(s.b);
            if (!Ok(S, V, a) || !Ok(S, V, b)) continue;

            Vector3 dir = P[b] - P[a];
            if (dir.sqrMagnitude < 1e-6f) continue;

            Quaternion target = Quaternion.FromToRotation(s.restDir, dir.normalized) * s.restRot;
            s.t.rotation = Quaternion.Slerp(s.t.rotation, target, 0.6f);
        }
    }
}