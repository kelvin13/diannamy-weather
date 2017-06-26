import OpenGL
import SwiftCairo

final
class Billboard
{
    let surface:CairoSurface,
        context:CairoContext

    private
    var mesh:MeshResource,
        texture:StreamableTexture2DResource

    private
    let u:Float,
        v:Float,
        width:CInt,
        height:CInt

    init(u:Float, v:Float, width h:CInt, height k:CInt, frame_width:CInt, frame_height:CInt)
    {
        self.u = u
        self.v = v
        self.width = h
        self.height = k

        let coordinates:[Float] = Billboard.generate_uv_coordinates(u: u, v: v, width: h, height: k, frame_width: frame_width, frame_height: frame_height)
        guard let mesh = MeshResource(coordinates: coordinates, indices: [0, 1, 2, 0, 2, 3], layout: [2, 2])
        else
        {
            fatalError("failed to make mesh")
        }
        self.mesh = mesh
        guard let surface = CairoSurface(format: .argb32, width: abs(h), height: abs(k))
        else
        {
            fatalError("failed to make Cairo surface")
        }
        self.surface = surface
        self.context = self.surface.create()

        self.texture = self.surface.with_data
        {
            return StreamableTexture2DResource(pixbuf: $0, width: abs(h), height: abs(k), format: .argb_per_int32, linear: false)
        }
    }

    deinit
    {
        self.mesh.release_resources()
        self.texture.release_resources()
    }

    func rescale(frame_width:CInt, frame_height:CInt)
    {
        let coordinates:[Float] = Billboard.generate_uv_coordinates(u: self.u, v: self.v, width: self.width, height: self.height,
                                                                    frame_width: frame_width, frame_height: frame_height)
        self.mesh.replace_coordinates(with: coordinates)
    }

    func shade()
    {
        glUseProgram(Shaders.billboard.program)

        glUniform1i(Shaders.billboard.tex_u_ids[0], 0)
        glActiveTexture(GL.TEXTURE0)
        glBindTexture(GL.TEXTURE_2D, self.texture.tex_id)

        glBindVertexArray(array: self.mesh.VAO)
        glDrawElements(GL.TRIANGLES, self.mesh.n, GL.UNSIGNED_INT, nil)

        glBindVertexArray(0)
        glBindTexture(GL.TEXTURE_2D, 0)
    }

    func update()
    {
        self.surface.with_data
        {
            self.texture.update_texture(pixbuf: $0)
        }
    }

    func clear()
    {
        self.surface.with_data
        {
            (pixbuf:UnsafeMutableBufferPointer<UInt8>) in

            for i in stride(from: 3, to: pixbuf.count, by: 4)
            {
                pixbuf[i] = 0;
            }
        }
    }

    private static
    func generate_uv_coordinates(u u1:Float, v v1:Float, width h:CInt, height k:CInt, frame_width:CInt, frame_height:CInt) -> [Float]
    {
        let u2:Float  = u1 + Float(2*h) / Float(frame_width),
            v2:Float  = v1 + Float(2*k) / Float(frame_height)

        let invert_u:Bool = (u1 > u2),
            left:Float    = invert_u ? u2 : u1,
            right:Float   = invert_u ? u1 : u2

        let invert_v:Bool = (v1 > v2),
            top:Float     = invert_v ? v1 : v2,
            bottom:Float  = invert_v ? v2 : v1

        return [left , bottom, 0, 1, // reversed v coordinates because the pixbuf is upside-down
                right, bottom, 1, 1,
                right, top   , 1, 0,
                left , top   , 0, 0]
    }
}
