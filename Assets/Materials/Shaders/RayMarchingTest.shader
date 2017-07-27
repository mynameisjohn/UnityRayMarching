Shader "ImageFX/RayMarchingTest"
{

	Properties
	{
		_MainTex ( "Texture", 2D ) = "white" {}
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

			// ray marching
			static const int max_iterations = 512;
			static const float stop_threshold = 0.001;
			static const float grad_step = 0.02;
			static const float clip_far = 1000.0;

			static const float PI = 3.14159265359;
			static const float DEG_TO_RAD = PI / 180.0;

			// iq's distance function
			float sdSphere( float3 pos, float r )
			{
				return length( pos ) - r;
			}

			float sdBox( float3 p, float3 b )
			{
				float3 d = abs( p ) - b;
				return min( max( d.x, max( d.y, d.z ) ), 0.0 ) + length( max( d, 0.0 ) );
			}

			// get distance in the world
			float dist_field( float3 pos )
			{
				float v = sdBox( pos, float3(0.5, 0.5, 0.5) );

				v = max( v, -sdSphere( pos, 0.6 ) );

				return v;
			}

			// get gradient in the world
			float3 gradient( float3 pos )
			{
				const float3 dx = float3(grad_step, 0.0, 0.0);
				const float3 dy = float3(0.0, grad_step, 0.0);
				const float3 dz = float3(0.0, 0.0, grad_step);
				return normalize (
					float3(
						dist_field( pos + dx ) - dist_field( pos - dx ),
						dist_field( pos + dy ) - dist_field( pos - dy ),
						dist_field( pos + dz ) - dist_field( pos - dz )
					)
				);
			}

			// phong shading
			float3 shading( float3 v, float3 n, float3 eye )
			{
				// ...add lights here...

				float shininess = 16.0;

				float3 final = float3(0, 0, 0);

				float3 ev = normalize( v - eye );
				float3 ref_ev = reflect( ev, n );

				// light 0
				{
					float3 light_pos = float3(20.0, 20.0, 20.0);
					float3 light_color = float3(1.0, 0.7, 0.7);

					float3 vl = normalize( light_pos - v );

					float diffuse = max( 0.0, dot( vl, n ) );
					float specular = max( 0.0, dot( vl, ref_ev ) );
					specular = pow( specular, shininess );

					final += light_color * (diffuse + specular);
				}

				// light 1
				{
					float3 light_pos = float3(-20.0, -20.0, -20.0);
					float3 light_color = float3(0.3, 0.7, 1.0);

					float3 vl = normalize( light_pos - v );

					float diffuse = max( 0.0, dot( vl, n ) );
					float specular = max( 0.0, dot( vl, ref_ev ) );
					specular = pow( specular, shininess );

					final += light_color * (diffuse + specular);
				}

				return final;
			}

			// ray marching
			float ray_marching( float3 origin, float3 dir, float start, float end )
			{
				float depth = start;
				for ( int i = 0; i < max_iterations; i++ )
				{
					float3 p = origin + dir * depth;
					float dist = dist_field( p ) / length( gradient( p ) );
					if ( abs( dist ) < stop_threshold )
					{
						return depth;
					}
					depth += dist * 0.9;
					if ( depth >= end )
					{
						return end;
					}
				}
				return end;
			}

			// get ray direction
			float3 ray_dir( float fov, float2 size, float2 pos )
			{
				float2 xy = pos - size * 0.5;

				float cot_half_fov = tan( (90.0 - fov * 0.5) * DEG_TO_RAD );
				float z = size.y * 0.5 * cot_half_fov;

				return normalize( float3(xy, -z) );
			}

			// camera rotation : pitch, yaw
			float3x3 rotationXY( float2 angle )
			{
				float2 c = cos( angle );
				float2 s = sin( angle );

				return float3x3(
					c.y, 0.0, -s.y,
					s.y * s.x, c.x, c.y * s.x,
					s.y * c.x, -s.x, c.y * c.x
				);
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
				fixed4 col;

				float3 f3Dir = ray_dir( 45.0, _MainTex_TexelSize.zw, i.vertex.xy );
				float3 f3Eye = float3(0,0,2.5);

				float3x3 f33Rot = rotationXY( float2(_Time.x, _Time.x) );
				f3Dir = mul( f33Rot, f3Dir );
				f3Eye = mul( f33Rot, f3Eye );

				float fDepth = ray_marching( f3Eye, f3Dir, 0, clip_far );
				if ( fDepth >= clip_far )
				{
					col = fixed4( 0.3, 0.4, 0.5, 1.0 );
				}
				else
				{
					// shading
					float3 pos = f3Eye + f3Dir * fDepth;
					float3 n = gradient( pos );
					col = fixed4( shading( pos, n, f3Eye ), 1.0 );
					// col = 1 - fixed4( 0.3, 0.4, 0.5, 1.0 );
				}
				return col;
			}
			ENDCG
		}
	}
}
