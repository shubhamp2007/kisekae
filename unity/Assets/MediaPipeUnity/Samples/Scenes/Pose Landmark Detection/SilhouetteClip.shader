Shader "Custom/SilhouetteClip"
{
    Properties
    {
        _MaskTex ("Mask", 2D) = "black" {}
    }
    SubShader
    {
        Tags { "Queue"="Geometry-20" "RenderType"="Opaque" }
        Pass
        {
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MaskTex;
            float4 _MaskOrigin;
            float4 _MaskEx;
            float4 _MaskEy;
            float4 _UVRect;
            float4 _Channel;
            float _Threshold;
            float _Dilate;

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 sp : TEXCOORD0;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.sp = ComputeScreenPos(o.pos);
                return o;
            }

            float samplePerson(float2 uv)
            {
                return dot(tex2Dlod(_MaskTex, float4(uv, 0, 0)), _Channel);
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float2 px = (i.sp.xy / i.sp.w) * _ScreenParams.xy;
                float2 rel = px - _MaskOrigin.xy;
                float det = _MaskEx.x * _MaskEy.y - _MaskEx.y * _MaskEy.x;
                if (abs(det) < 1e-5)
                {
                    clip(-1);
                }

                float u = (rel.x * _MaskEy.y - rel.y * _MaskEy.x) / det;
                float v = (_MaskEx.x * rel.y - _MaskEx.y * rel.x) / det;

                float person = 0;
                if (u >= 0 && u <= 1 && v >= 0 && v <= 1)
                {
                    float2 muv = _UVRect.xy + float2(u, v) * _UVRect.zw;
                    float d = _Dilate;
                    person = samplePerson(muv);
                    person = max(person, samplePerson(muv + float2(d, 0)));
                    person = max(person, samplePerson(muv - float2(d, 0)));
                    person = max(person, samplePerson(muv + float2(0, d)));
                    person = max(person, samplePerson(muv - float2(0, d)));
                }

                clip(_Threshold - person);
                return fixed4(0, 0, 0, 0);
            }
            ENDCG
        }
    }
}
