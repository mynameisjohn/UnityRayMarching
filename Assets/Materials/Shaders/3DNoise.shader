Shader "ImageFX/3DNoise"
{

	Properties
	{
		_MainTex ( "Texture", 2D ) = "white" {}
		_Color ( "Color", Color ) = (0.085, 0.658, 1.0, 1.0)
	}
		SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			static const float FOV = 0.4;
			static const float MarchDumping = 0.7579;
			static const float Far = 38.925;
			static const int MaxSteps = 128;
			static const float CameraSpeed = 4.5099998;
			static const float TunnelSmoothFactor = 2.0;
			static const float TunnelRadius = 0.85660005;
			static const float TunnelFreqA = 0.18003;
			static const float TunnelFreqB = 0.25;
			static const float TunnelAmpA = 3.6230998;
			static const float TunnelAmpB = 2.4324;
			static const float NoiseIsoline = 0.319;
			static const float NoiseScale = 2.9980001;
			static const float M_NONE = -1;
			static const float M_NOISE = 1;
			const float3 _Color;

			float hash( float h )
			{
				return frac( sin( h ) * 43758.5453123 );
			}

			float noise( float3 x )
			{
				float3 p = floor( x );
				float3 f = frac( x );
				f = f * f * (3.0 - 2.0 * f);

				float n = p.x + p.y * 157.0 + 113.0 * p.z;
				return lerp(
					lerp( lerp( hash( n + 0.0 ), hash( n + 1.0 ), f.x ),
						 lerp( hash( n + 157.0 ), hash( n + 158.0 ), f.x ), f.y ),
					lerp( lerp( hash( n + 113.0 ), hash( n + 114.0 ), f.x ),
						 lerp( hash( n + 270.0 ), hash( n + 271.0 ), f.x ), f.y ), f.z );
			}

			float fbm( float3 p )
			{
				float f = 0.0;
				f = 0.5000 * noise( p );
				p *= 2.01;
				f += 0.2500 * noise( p );
				p *= 2.02;
				f += 0.1250 * noise( p );

				return f;
			}

			// From "Subterranean Fly-Through" by Shane https://www.shadertoy.com/view/XlXXWj
			float2 path( float z )
			{
				return float2(TunnelAmpA * sin( z * TunnelFreqA ), TunnelAmpB * cos( z * TunnelFreqB ));
			}


			// by iq. http://iquilezles.org/www/articles/smin/smin.htm
			float smax( float a, float b, float k )
			{
				float h = clamp( 0.5 + 0.5 * (b - a) / k, 0.0, 1.0 );
				return lerp( a, b, h ) + k * h * (1.0 - h);
			}

			float noiseDist( float3 p )
			{
				p = p / NoiseScale;
				return (fbm( p ) - NoiseIsoline) * NoiseScale;
			}

			float2 map( float3 p )
			{
				float d = noiseDist( p );
				float d2 = length( p.xy - path( p.z ) ) - TunnelRadius;
				d = smax( d, -d2, TunnelSmoothFactor );

				float2 res = float2( d, M_NOISE );
				return res;
			}

			float2 castRay( float3 ro, float3 rd )
			{
				float tmin = 0.0;
				float tmax = Far;

				float precis = 0.002;
				float t = tmin;
				float m = M_NONE;

				for ( int i = 0; i < MaxSteps; i++ )
				{
					float2 res = map( ro + rd * t );
					if ( res.x < precis || t > tmax )
					{
						break;
					}
					t += res.x * MarchDumping;
					m = res.y;
				}
				if ( t > tmax )
				{
					m = M_NONE;
				}
				return float2( t, m );
			}


			float softshadow( float3 ro, float3 rd, float mint, float tmax )
			{
				float res = 1.0;
				float t = mint;

				for ( int i = 0; i < 16; i++ )
				{
					float h = map( ro + rd * t ).x;

					res = min( res, 8.0 * h / t );
					t += clamp( h, 0.02, 0.10 );

					if ( h < 0.001 || t > tmax )
					{
						break;
					}
				}
				return clamp( res, 0.0, 1.0 );
			}

			float3 calcNormal( float3 pos )
			{
				float2 eps = float2( 0.001, 0.0 );

				float3 nor = float3( map( pos + eps.xyy ).x - map( pos - eps.xyy ).x,
								 map( pos + eps.yxy ).x - map( pos - eps.yxy ).x,
								 map( pos + eps.yyx ).x - map( pos - eps.yyx ).x );
				return normalize( nor );
			}

			float calcAO( float3 pos, float3 nor )
			{
				float occ = 0.0;
				float sca = 1.0;

				for ( int i = 0; i < 5; i++ )
				{
					float hr = 0.01 + 0.12 * float( i ) / 4.0;
					float3 aopos = nor * hr + pos;
					float dd = map( aopos ).x;

					occ += -(dd - hr) * sca;
					sca *= 0.95;
				}
				return clamp( 1.0 - 3.0 * occ, 0.0, 1.0 );
			}

			float3x3 rotationZ( float a )
			{
				float sa = sin( a );
				float ca = cos( a );

				return float3x3( ca, sa, 0.0, -sa, ca, 0.0, 0.0, 0.0, 1.0 );
			}

			float3 render( float3 ro, float3 rd )
			{
				float3 col = float3( 0, 0, 0 );
				float2 res = castRay( ro, rd );
				float t = res.x;
				float m = res.y;

				if ( m > -0.5 )
				{
					float3 pos = ro + t * rd;
					float3 nor = calcNormal( pos );

					// material
					col = _Color.rgb + sin( t * 0.8 ) * 0.3;
					col += 0.3 * sin( float3( 0.15, 0.02, 0.10 ) * _Time.x * 6.0 );

					// lighitng
					float occ = calcAO( pos, nor );
					float3 lig = -rd;
					float amb = clamp( 0.5 + 0.5 * nor.y, 0.0, 1.0 );
					float dif = clamp( dot( nor, lig ), 0.0, 1.0 );

					float fre = pow( clamp( 1.0 + dot( nor, rd ), 0.0, 1.0 ), 2.0 );

					float3 ref = reflect( rd, nor );
					float spe = pow( clamp( dot( ref, lig ), 0.0, 1.0 ), 100.0 );

					dif *= softshadow( pos, lig, 0.02, 2.5 );

					float3 brdf = float3( 0, 0, 0 );
					brdf += 1.20 * dif * float3( 1.00, 0.90, 0.60 );
					brdf += 1.20 * spe * float3( 1.00, 0.90, 0.60 ) * dif;

					// Additional specular lighting trick,
					// taken from "Wet stone" by TDM
					// https://www.shadertoy.com/view/ldSSzV
					nor = normalize( nor - normalize( pos ) * 0.2 );
					ref = reflect( rd, nor );
					spe = pow( clamp( dot( ref, lig ), 0.0, 1.0 ), 100.0 );
					brdf += 2.20 * spe * float3( 1.00, 0.90, 0.60 ) * dif;

					brdf += 0.40 * amb * float3( 0.50, 0.70, 1.00 ) * occ;
					brdf += 0.40 * fre * float3( 1.00, 1.00, 1.00 ) * occ;

					col = col * brdf;

					col = lerp( col, float3( 0, 0, 0 ), 1.0 - exp( -0.005 * t * t ) );
				}
				return float3( clamp( col, 0.0, 1.0 ) );
			}

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert ( appdata v )
			{
				v2f o;
				o.vertex = UnityObjectToClipPos( v.vertex );
				o.uv = v.uv;
				return o;
			}

			sampler2D _MainTex;
			float4 _MainTex_TexelSize;

			fixed4 frag ( v2f i ) : SV_Target
			{
				float2 q = i.vertex.xy / _MainTex_TexelSize.zw;
				float2 coord = 2.0 * q - 1.0;
				coord.x *= _MainTex_TexelSize.z / _MainTex_TexelSize.w;
				coord *= FOV;

				float t = _Time.x * CameraSpeed + 4.0 * 60.0;
				float3 ro = float3( path( t ), t );

				t += 0.5;
				float3 target = float3( path( t ), t );
				float3 dir = normalize( target - ro );
				float3 up = float3(-0.9309864, -0.33987653, 0.1332234);
				up = mul( up, rotationZ( _Time.x * 0.05 ) );
				float3 upOrtho = normalize( up - dot( dir, up ) * dir );
				float3 right = normalize( cross( dir, upOrtho ) );

				float3 rd = normalize( dir + coord.x * right + coord.y * upOrtho );

				float3 col = render( ro, rd );

				col = pow( col, float3( 0.4545, 0.4545, 0.4545 ) );

				return fixed4( col, 1.0 );
			}
			ENDCG
		}
	}
}
