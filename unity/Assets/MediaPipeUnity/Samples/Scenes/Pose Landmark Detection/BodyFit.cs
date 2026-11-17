using System;
using System.Collections.Generic;
using UnityEngine;

public class BodyFit : MonoBehaviour
{
    public PoseDriver driver;
    public Animator animator;
    public float minVisibility = 0.7f;
    public int sampleCount = 90;
    public float updateInterval = 0.5f;
    public float lockAfterSeconds = 8f;
    public float resetAfterAbsence = 4f;
    public float minFactor = 0.7f;
    public float maxFactor = 1.4f;
    [Range(0.01f, 1f)] public float blend = 0.25f;
    public bool logFactors;

    const int Count = 7;
    const int UpperArm = 1;
    const int ForeArm = 2;
    const int Thigh = 3;
    const int Shin = 4;
    const int ShoulderWidth = 5;
    const int HipWidth = 6;

    class Joint
    {
        public Transform t;
        public Vector3 restLocal;
    }

    class Median
    {
        readonly float[] buf;
        int head;
        public int Count;

        public Median(int size) { buf = new float[size]; }

        public void Add(float v)
        {
            buf[head] = v;
            head = (head + 1) % buf.Length;
            if (Count < buf.Length) Count++;
        }

        public void Clear()
        {
            head = 0;
            Count = 0;
        }

        public float Value()
        {
            if (Count == 0) return 0f;
            var tmp = new float[Count];
            Array.Copy(buf, tmp, Count);
            Array.Sort(tmp);
            return tmp[Count / 2];
        }
    }

    readonly List<Joint> lowerArms = new List<Joint>();
    readonly List<Joint> hands = new List<Joint>();
    readonly List<Joint> lowerLegs = new List<Joint>();
    readonly List<Joint> feet = new List<Joint>();
    readonly List<Joint> shoulderJoints = new List<Joint>();
    readonly List<Joint> hipJoints = new List<Joint>();

    readonly float[] avatarRatio = new float[Count];
    readonly float[] applied = new float[Count];
    Median[] medians;

    float sampleTimer;
    float updateTimer;
    float calibTime;
    float absent;
    bool locked;
    bool ready;

    void Start()
    {
        if (driver == null) driver = GetComponent<PoseDriver>();
        if (animator == null && driver != null) animator = driver.animator;
        if (animator == null) animator = GetComponentInChildren<Animator>();

        if (driver == null || animator == null || !animator.isHuman)
        {
            Debug.LogError("BodyFit: needs a PoseDriver and a Humanoid Animator.");
            enabled = false;
            return;
        }

        Transform lua = Bone(HumanBodyBones.LeftUpperArm);
        Transform rua = Bone(HumanBodyBones.RightUpperArm);
        Transform lla = Bone(HumanBodyBones.LeftLowerArm);
        Transform rla = Bone(HumanBodyBones.RightLowerArm);
        Transform lh = Bone(HumanBodyBones.LeftHand);
        Transform rh = Bone(HumanBodyBones.RightHand);
        Transform lul = Bone(HumanBodyBones.LeftUpperLeg);
        Transform rul = Bone(HumanBodyBones.RightUpperLeg);
        Transform lll = Bone(HumanBodyBones.LeftLowerLeg);
        Transform rll = Bone(HumanBodyBones.RightLowerLeg);
        Transform lf = Bone(HumanBodyBones.LeftFoot);
        Transform rf = Bone(HumanBodyBones.RightFoot);

        if (lua == null || rua == null || lla == null || rla == null || lh == null || rh == null ||
            lul == null || rul == null || lll == null || rll == null || lf == null || rf == null)
        {
            Debug.LogError("BodyFit: the Humanoid avatar is missing arm or leg bones.");
            enabled = false;
            return;
        }

        float torso = Vector3.Distance((lua.position + rua.position) * 0.5f, (lul.position + rul.position) * 0.5f);
        if (torso < 1e-4f)
        {
            Debug.LogError("BodyFit: invalid torso measurement.");
            enabled = false;
            return;
        }

        avatarRatio[UpperArm] = (Vector3.Distance(lua.position, lla.position) + Vector3.Distance(rua.position, rla.position)) * 0.5f / torso;
        avatarRatio[ForeArm] = (Vector3.Distance(lla.position, lh.position) + Vector3.Distance(rla.position, rh.position)) * 0.5f / torso;
        avatarRatio[Thigh] = (Vector3.Distance(lul.position, lll.position) + Vector3.Distance(rul.position, rll.position)) * 0.5f / torso;
        avatarRatio[Shin] = (Vector3.Distance(lll.position, lf.position) + Vector3.Distance(rll.position, rf.position)) * 0.5f / torso;
        avatarRatio[ShoulderWidth] = Vector3.Distance(lua.position, rua.position) / torso;
        avatarRatio[HipWidth] = Vector3.Distance(lul.position, rul.position) / torso;

        Add(lowerArms, lla);
        Add(lowerArms, rla);
        Add(hands, lh);
        Add(hands, rh);
        Add(lowerLegs, lll);
        Add(lowerLegs, rll);
        Add(feet, lf);
        Add(feet, rf);

        Transform ls = Bone(HumanBodyBones.LeftShoulder);
        Transform rs = Bone(HumanBodyBones.RightShoulder);
        if (ls != null && rs != null)
        {
            Add(shoulderJoints, ls);
            Add(shoulderJoints, rs);
        }
        Add(shoulderJoints, lua);
        Add(shoulderJoints, rua);

        Add(hipJoints, lul);
        Add(hipJoints, rul);

        medians = new Median[Count];
        for (int i = 0; i < Count; i++)
        {
            medians[i] = new Median(Mathf.Max(10, sampleCount));
            applied[i] = 1f;
        }

        ready = true;
    }

    Transform Bone(HumanBodyBones b)
    {
        return animator.GetBoneTransform(b);
    }

    static void Add(List<Joint> list, Transform t)
    {
        list.Add(new Joint { t = t, restLocal = t.localPosition });
    }

    [ContextMenu("Recalibrate")]
    public void Recalibrate()
    {
        if (!ready) return;
        for (int i = 0; i < Count; i++) medians[i].Clear();
        locked = false;
        calibTime = 0f;
        sampleTimer = 0f;
        updateTimer = 0f;
    }

    [ContextMenu("Reset Proportions")]
    void ResetProportions()
    {
        if (!ready) return;
        for (int i = 0; i < Count; i++) applied[i] = 1f;
        ApplyFactors();
        Recalibrate();
    }

    bool Get(int idx, out Vector3 p)
    {
        return driver.TryGetWorld(idx, minVisibility, out p);
    }

    void Sample()
    {
        Vector3 ls, rs, lh, rh;
        if (!Get(11, out ls) || !Get(12, out rs) || !Get(23, out lh) || !Get(24, out rh)) return;

        float torso = Vector3.Distance((ls + rs) * 0.5f, (lh + rh) * 0.5f);
        if (torso < 0.1f) return;

        medians[ShoulderWidth].Add(Vector3.Distance(ls, rs) / torso);
        medians[HipWidth].Add(Vector3.Distance(lh, rh) / torso);
        calibTime += 0.1f;

        Vector3 le, re, lw, rw, lk, rk, la, ra;

        if (Get(13, out le) && Get(14, out re))
        {
            medians[UpperArm].Add((Vector3.Distance(ls, le) + Vector3.Distance(rs, re)) * 0.5f / torso);

            if (Get(15, out lw) && Get(16, out rw))
                medians[ForeArm].Add((Vector3.Distance(le, lw) + Vector3.Distance(re, rw)) * 0.5f / torso);
        }

        if (Get(25, out lk) && Get(26, out rk))
        {
            medians[Thigh].Add((Vector3.Distance(lh, lk) + Vector3.Distance(rh, rk)) * 0.5f / torso);

            if (Get(27, out la) && Get(28, out ra))
                medians[Shin].Add((Vector3.Distance(lk, la) + Vector3.Distance(rk, ra)) * 0.5f / torso);
        }
    }

    void UpdateFactors()
    {
        bool changed = false;
        for (int i = 1; i < Count; i++)
        {
            if (medians[i].Count < 20) continue;
            float user = medians[i].Value();
            float target = Mathf.Clamp(user / avatarRatio[i], minFactor, maxFactor);
            applied[i] = Mathf.Lerp(applied[i], target, blend);
            changed = true;

            if (logFactors) Debug.Log("BodyFit factor " + i + " = " + applied[i].ToString("F3"));
        }
        if (changed) ApplyFactors();
    }

    void ApplyFactors()
    {
        Scale(lowerArms, applied[UpperArm]);
        Scale(hands, applied[ForeArm]);
        Scale(lowerLegs, applied[Thigh]);
        Scale(feet, applied[Shin]);
        Scale(shoulderJoints, applied[ShoulderWidth]);
        Scale(hipJoints, applied[HipWidth]);
    }

    static void Scale(List<Joint> joints, float k)
    {
        foreach (var j in joints)
        {
            if (j.t != null) j.t.localPosition = j.restLocal * k;
        }
    }

    void Update()
    {
        if (!ready) return;

        if (!driver.WorldFresh)
        {
            absent += Time.deltaTime;
            if (absent > resetAfterAbsence && (locked || calibTime > 0f))
            {
                Recalibrate();
            }
            return;
        }
        absent = 0f;

        if (locked) return;

        sampleTimer += Time.deltaTime;
        if (sampleTimer >= 0.1f)
        {
            sampleTimer = 0f;
            Sample();
        }

        updateTimer += Time.deltaTime;
        if (updateTimer >= updateInterval)
        {
            updateTimer = 0f;
            UpdateFactors();

            if (calibTime >= lockAfterSeconds)
            {
                locked = true;
                for (int k = 0; k < 6; k++) UpdateFactors();
            }
        }
    }
}