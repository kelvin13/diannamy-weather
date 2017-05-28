import func Glibc.sin
import func Glibc.cos
import func Glibc.tan

func make_sphere_plate(subdivisions:Int, radius:Float, normal:Vector3D<Float>, tangent:Vector3D<Float>,
 coordinates:inout [Float], indices triangles:inout [Int], offset:Int) -> Int
{
    let δ:Float = 0.5 * Float.pi / Float(subdivisions)
    let bitangent:Vector3D<Float> = normal.cross(tangent) // tangent should point “right” and bitangent should point “up”
    //let unradian = 1.0/π_4

    var α:Float = -0.25 * Float.pi
    for rowcount in 0 ... subdivisions
    {
        let a:Float = tan(α)
        //  σ:Float = α*unradian
        var β:Float = -0.25 * Float.pi
        for partcount in 0...subdivisions
        {
            let b:Float = tan(β)
            //  τ:Double = β*unradian
            let x = normal.x - a*tangent.x + b*bitangent.x,
                y = normal.y - a*tangent.y + b*bitangent.y,
                z = normal.z - a*tangent.z + b*bitangent.z
            /*
                s = normal.x - σ*tangent.x + τ*bitangent.x,
                t = normal.y - σ*tangent.y + τ*bitangent.y,
                r = normal.z - σ*tangent.z + τ*bitangent.z
            */
            let n_inv:Float = 1 / (x*x + y*y + z*z).squareRoot(),
                r_inv:Float = radius * n_inv
            // spatial coordinates
            coordinates.append(x * r_inv)
            coordinates.append(y * r_inv)
            coordinates.append(z * r_inv)
            // cube map coordinates
            /*
            coordinates.append(s)
            coordinates.append(t)
            coordinates.append(r)
            */
            // vertex normal coordinates
            coordinates.append(x * n_inv)
            coordinates.append(y * n_inv)
            coordinates.append(z * n_inv)
            if rowcount != 0 && partcount != 0 // edge catch
            {
                let lead_vertex   = offset + rowcount*(subdivisions + 1) + partcount
                let left_vertex   = lead_vertex - 1
                let bottom_vertex = lead_vertex - (subdivisions + 1)
                let root_vertex   = bottom_vertex - 1
                if (b < 0) == (a < 0) // check if b and a have the same sign
                {
                    triangles += [root_vertex, lead_vertex, left_vertex,    // ←↗
                                  root_vertex, bottom_vertex, lead_vertex]  // →↑
                }
                else
                {
                    triangles += [root_vertex, bottom_vertex, left_vertex,  // →↖
                                  lead_vertex, left_vertex, bottom_vertex]  // ↘←
                }
            }

            β += δ
        }
        α += δ
    }
    return (subdivisions + 1)*(subdivisions + 1)
}

public
func make_sphere(radius:Float, subdivisions:Int) -> ([Float], [Int])
{
    var C:[Float] = [],
        I:[Int]   = []
    var offset:Int = 0
    for (normal, tangent) in [(Vector3D<Float>( 0,  0,  1), Vector3D<Float>( 1,  0, 0)),
                              (Vector3D<Float>( 1,  0,  0), Vector3D<Float>( 0,  1, 0)),
                              (Vector3D<Float>( 0,  1,  0), Vector3D<Float>(-1,  0, 0)),
                              (Vector3D<Float>(-1,  0,  0), Vector3D<Float>( 0, -1, 0)),
                              (Vector3D<Float>( 0, -1,  0), Vector3D<Float>( 1,  0, 0)),
                              (Vector3D<Float>( 0,  0, -1), Vector3D<Float>(-1,  0, 0))]
    {
        offset += make_sphere_plate(subdivisions: subdivisions, radius: radius,
                                    normal: normal,
                                    tangent: tangent,
                                    coordinates: &C,
                                    indices: &I,
                                    offset: offset)
    }
    return (C, I)
}
