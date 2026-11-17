using System;
using System.Collections.Generic;
using UnityEngine;

public class OutfitManager : MonoBehaviour
{
    [Serializable]
    public class Slot
    {
        public string name;
        public GameObject[] options;
        [NonSerialized] public GameObject spawned;
    }

    public Transform avatarRoot;
    public Animator animator;
    public ArFit arFit;
    public Slot[] slots;
    public GameObject[] prefabLibrary;
    public string[] skipKeywords = { "body", "skin", "human", "eye", "brow", "lash", "teeth", "tongue", "hair" };
    public bool hideOptionsAtStart = true;

    readonly Dictionary<string, Transform> boneMap = new Dictionary<string, Transform>();

    void Start()
    {
        if (avatarRoot == null) avatarRoot = transform;
        if (animator == null) animator = avatarRoot.GetComponentInChildren<Animator>();

        foreach (var t in avatarRoot.GetComponentsInChildren<Transform>(true))
        {
            if (!boneMap.ContainsKey(t.name)) boneMap.Add(t.name, t);
        }

        if (hideOptionsAtStart && slots != null)
        {
            foreach (var s in slots) SetOptionsActive(s, null);
        }
    }

    public string startSlot;
    public string startOption;
    bool startApplied;

    void Update()
    {
        if (startApplied) return;
        startApplied = true;
        if (!string.IsNullOrEmpty(startSlot) && !string.IsNullOrEmpty(startOption)) Select(startSlot, startOption);
    }

    public void SetGarment(string arg)
    {
        if (string.IsNullOrEmpty(arg)) return;
        int i = arg.IndexOf(':');
        if (i <= 0 || i >= arg.Length - 1)
        {
            Debug.LogWarning("OutfitManager: expected 'slot:option', got '" + arg + "'");
            return;
        }
        Select(arg.Substring(0, i), arg.Substring(i + 1));
    }

    public void ClearGarment(string slotName)
    {
        Clear(slotName);
    }

    public void Select(string slotName, string optionName)
    {
        var slot = FindSlot(slotName);
        if (slot == null)
        {
            Debug.LogWarning("OutfitManager: no slot named " + slotName);
            return;
        }

        ClearSpawned(slot);

        GameObject chosen = null;
        if (slot.options != null)
        {
            foreach (var o in slot.options)
            {
                if (o != null && o.name == optionName) chosen = o;
            }
        }

        SetOptionsActive(slot, chosen);

        if (chosen == null)
        {
            var prefab = FindPrefab(optionName);
            if (prefab != null) slot.spawned = Spawn(prefab, slotName);
            else Debug.LogWarning("OutfitManager: no option or prefab named " + optionName);
        }

        Refresh();
    }

    public void Clear(string slotName)
    {
        var slot = FindSlot(slotName);
        if (slot == null) return;
        ClearSpawned(slot);
        SetOptionsActive(slot, null);
        Refresh();
    }

    Slot FindSlot(string slotName)
    {
        if (slots == null) return null;
        foreach (var s in slots)
        {
            if (s != null && s.name == slotName) return s;
        }
        return null;
    }

    GameObject FindPrefab(string optionName)
    {
        if (prefabLibrary == null) return null;
        foreach (var p in prefabLibrary)
        {
            if (p != null && p.name == optionName) return p;
        }
        return null;
    }

    void SetOptionsActive(Slot slot, GameObject active)
    {
        if (slot == null || slot.options == null) return;
        foreach (var o in slot.options)
        {
            if (o != null) o.SetActive(o == active);
        }
    }

    void ClearSpawned(Slot slot)
    {
        if (slot.spawned != null)
        {
            Destroy(slot.spawned);
            slot.spawned = null;
        }
    }

    bool IsSkipped(string meshName)
    {
        string lower = meshName.ToLowerInvariant();
        foreach (var k in skipKeywords)
        {
            if (!string.IsNullOrEmpty(k) && lower.Contains(k.ToLowerInvariant())) return true;
        }
        return false;
    }

    GameObject Spawn(GameObject prefab, string slotName)
    {
        var instance = Instantiate(prefab);
        var holder = new GameObject(slotName + "_" + prefab.name);
        holder.transform.SetParent(avatarRoot, false);

        foreach (var smr in instance.GetComponentsInChildren<SkinnedMeshRenderer>(true))
        {
            if (IsSkipped(smr.name)) continue;
            Rebind(smr);
            smr.transform.SetParent(holder.transform, false);
        }

        Destroy(instance);
        return holder;
    }

    void Rebind(SkinnedMeshRenderer smr)
    {
        var source = smr.bones;
        var target = new Transform[source.Length];
        int missing = 0;

        for (int i = 0; i < source.Length; i++)
        {
            if (source[i] != null && boneMap.TryGetValue(source[i].name, out var t)) target[i] = t;
            else missing++;
        }

        smr.bones = target;

        if (smr.rootBone != null && boneMap.TryGetValue(smr.rootBone.name, out var root)) smr.rootBone = root;
        else if (animator != null) smr.rootBone = animator.GetBoneTransform(HumanBodyBones.Hips);

        smr.updateWhenOffscreen = true;

        if (missing > 0)
            Debug.LogWarning("OutfitManager: " + smr.name + " has " + missing + " bones with no match on the avatar skeleton.");
    }

    void Refresh()
    {
        if (arFit != null) arFit.RefreshRenderers();
    }
}