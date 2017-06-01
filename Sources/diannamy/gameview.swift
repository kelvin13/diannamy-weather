import SGLOpenGL

import var Cairo.CAIRO_FONT_SLANT_NORMAL
import var Cairo.CAIRO_FONT_SLANT_ITALIC
import var Cairo.CAIRO_FONT_WEIGHT_BOLD
import var Cairo.CAIRO_FONT_WEIGHT_NORMAL

import Geometry

import Glibc
import Noise

enum Shaders
{
    static
    let billboard = Shader(vertex_file  : "Sources/Shaders/ui.vert",
                           fragment_file: "Sources/Shaders/ui.frag",
                           tex_uniforms : ["img"],
                           uniforms     : [])!
    static
    let vertcolor = Shader(vertex_file  : "Sources/Shaders/vertcolor.vert",
                           fragment_file: "Sources/Shaders/vertcolor.frag",
                           tex_uniforms : [],
                           uniforms     : ["model"])!
    static
    let cloudgen_shield  = Shader(vertex_file  : "Sources/Shaders/cloudgen.vert",
                           geometry_file: "Sources/Shaders/cloudgen-shield.geom",
                           fragment_file: "Sources/Shaders/cloudgen-shield.frag",
                           tex_uniforms : ["tex_cloud"],
                           uniforms     : ["model"])!
    static
    let cloudgen_kernel  = Shader(vertex_file  : "Sources/Shaders/cloudgen.vert",
                           geometry_file: "Sources/Shaders/cloudgen-kernel.geom",
                           fragment_file: "Sources/Shaders/cloudgen-kernel.frag",
                           tex_uniforms : ["tex_cloud"],
                           uniforms     : ["model"])!
    static
    let globe     = Shader(vertex_file  : "Sources/Shaders/planet.vert",
                           fragment_file: "Sources/Shaders/planet.frag",
                           tex_uniforms : ["tex_color_cube"],
                           uniforms     : ["model"])!
}

class FlowSphere
{
    private
    var point_coordinates:[Float],
        refresh_index:Int = 0

    private
    let cloudpoint_stride:Int,
        cloudpoint_refresh_rate:Double

    let point_mesh:MeshResource,
        field_mesh:MeshResource,
        ball_mesh:MeshResource

    let cloud_tex_shield:Texture2DResource,
        cloud_tex_kernel:Texture2DResource,
        globe_tex:CubeTextureResource

    var transform:Transform,
        θ:Double = 0

    private static
    let noise_gen:SuperSimplex3D = SuperSimplex3D(amplitude: 1/256, frequency: 1.8, seed: 1)
    private static
    func potential(_ x:Double, _ y:Double, _ z:Double, θ:Double) -> Double
    {
        var φ:Double = asin(z)
        if φ.isNaN
        {
            φ = z < 1 ? -0.5*Double.pi : 0.5*Double.pi
        }

        //let ICZ:Double = abs(φ) < Double.pi / 6 ? cos(6 * φ) + 1 : 0

        let s1:Double = sin(θ),
            c1:Double = cos(θ)

            //s2:Double = sin(-2*θ),
            //c2:Double = cos(-2*θ)

        let ferrel:Double = FlowSphere.noise_gen.evaluate(x*c1 - y*s1 + 1, x*s1 + y*c1 + 1, z + 1) - 0.25*cos(6 * φ)
            //hadley:Double = FlowSphere.noise_gen.evaluate(x*c2 - y*s2 + 1, x*s2 + y*c2 + 1, z + 1) - 0.15*cos(6 * φ)

        return ferrel// * (1 - ICZ) + hadley * ICZ
    }

    init(n:Int, lifetime:Double)
    {
        let cloudpoint_layout:[Int] = [3, 3, 2]
        self.cloudpoint_stride  = cloudpoint_layout.reduce(0, +)
        self.cloudpoint_refresh_rate = Double(n) / lifetime

        var points:[Float] = []
            points.reserveCapacity(n * self.cloudpoint_stride)
        var field:[Float] = []
            field.reserveCapacity(n * 12)
        let rand_scale:Double = 2 / Double(CInt.max)

        srand(0)
        var points_generated:Int = 0
        while points_generated < n
        {
            let x:Double = Double(rand()) * rand_scale - 1,
                y:Double = Double(rand()) * rand_scale - 1,
                z:Double = Double(rand()) * rand_scale - 1

            let r2:Double = x*x + y*y + z*z
            guard r2 <= 1
            else
            {
                continue
            }

            let normalize:Double   = 1 / r2.squareRoot(),
                position:Vector3D<Double> = Vector3D(x*normalize, y*normalize, z*normalize)

            points.append(Float(position.x))
            points.append(Float(position.y))
            points.append(Float(position.z))
            points.append(0)
            points.append(0)
            points.append(0)
            points.append(Float(lifetime))
            points.append(0)

            let curl:Vector3D<Float> = FlowSphere.curl(at: position)

            let slope:Float = 0.4 * curl.magnitude,
                scale:Float = 0.01
            field.append(Float(position.x) - scale * curl.x)
            field.append(Float(position.y) - scale * curl.y)
            field.append(Float(position.z) - scale * curl.z)
            field.append(slope)
            field.append(1 - abs(slope - 0.5))
            field.append(1 - slope)

            field.append(Float(position.x) + scale * curl.x)
            field.append(Float(position.y) + scale * curl.y)
            field.append(Float(position.z) + scale * curl.z)
            field.append(slope)
            field.append(1 - abs(slope - 0.5))
            field.append(1 - slope)

            points_generated += 1
        }

        self.point_coordinates = points
        guard let point_mesh:MeshResource = MeshResource(coordinates: points, indices: Array(0 ..< n), layout: cloudpoint_layout)
        else
        {
            fatalError("could not make sphere point mesh")
        }
        self.point_mesh = point_mesh

        guard let field_mesh:MeshResource = MeshResource(coordinates: field, indices: Array(0 ..< n << 1), layout: [3, 3])
        else
        {
            fatalError("could not make sphere gradient mesh")
        }
        self.field_mesh = field_mesh

        let (ball_coords, ball_indices):([Float], [Int]) = make_sphere(radius: 0.99, subdivisions: 8)
        guard let ball_mesh:MeshResource = MeshResource(coordinates: ball_coords, indices: ball_indices, layout: [3, 3])
        else
        {
            fatalError("could not make sphere ball mesh")
        }
        self.ball_mesh = ball_mesh

        self.cloud_tex_shield = Texture2DResource(png: "../Textures/shield1.png")!
        self.cloud_tex_kernel = Texture2DResource(png: "../Textures/cloud2.png")!
        self.globe_tex = CubeTextureResource(png_pattern: "../Textures/color_cube")!

        self.transform = Transform()
    }

    deinit
    {
        self.point_mesh.release_resources()
        self.field_mesh.release_resources()
        self.ball_mesh.release_resources()

        self.globe_tex.release_resources()
        self.cloud_tex_shield.release_resources()
        self.cloud_tex_kernel.release_resources()
    }

    func advance_points(dt:Double)
    {
        let rand_scale:Double = 2 / Double(CInt.max)
        let refresh:Int = Int(dt * self.cloudpoint_refresh_rate)
        var refreshed:Int = 0
        while refreshed < refresh
        {


            let x:Double = Double(rand()) * rand_scale - 1,
                y:Double = Double(rand()) * rand_scale - 1,
                z:Double = Double(rand()) * rand_scale - 1

            let r2:Double = x*x + y*y + z*z
            guard r2 <= 1
            else
            {
                continue
            }

            let normalize:Double   = 1 / r2.squareRoot(),
                position:Vector3D<Double> = Vector3D(x*normalize, y*normalize, z*normalize)

            self.point_coordinates[self.refresh_index    ] = Float(position.x)
            self.point_coordinates[self.refresh_index + 1] = Float(position.y)
            self.point_coordinates[self.refresh_index + 2] = Float(position.z)
            self.point_coordinates[self.refresh_index + 6] = 0 // age

            self.refresh_index = self.refresh_index + self.cloudpoint_stride >= self.point_coordinates.count ? 0 : self.refresh_index + self.cloudpoint_stride
            refreshed += 1
        }

        self.θ -= 0.15 * dt
        let cloud_speed:Float = Float(0.125 * dt)
        for i in stride(from: 0, to: self.point_coordinates.count, by: self.cloudpoint_stride)
        {
            let position:Vector3D<Double> = Vector3D(Double(self.point_coordinates[i]), Double(self.point_coordinates[i + 1]), Double(self.point_coordinates[i + 2]))

            //let velocity:Vector3D<Float>   = FlowSphere.curl(at: position, bias: -0.25, coriolis: 0),
            let deflection:Vector3D<Float> = FlowSphere.curl(at: position, θ: self.θ, bias: -0.25, coriolis: 2*position.z) // velocity - Vector3D(0, 0, 1).cross(velocity)

            var φ:Double = asin(position.z)
            if φ.isNaN
            {
                φ = position.z < 1 ? -0.5*Double.pi : 0.5*Double.pi
            }
            let ICZ:Double = cos(6 * φ)
            let trade_winds:(x:Float, y:Float) = (x: Float(ICZ*position.y), y: -Float(ICZ*position.x))

            let velocity:Vector3D<Float> = Vector3D(deflection.x + trade_winds.x, deflection.y + trade_winds.y, deflection.z)
            let point:Vector3D<Float> = Vector3D(self.point_coordinates[i    ] + cloud_speed * velocity.x,
                                                 self.point_coordinates[i + 1] + cloud_speed * velocity.y,
                                                 self.point_coordinates[i + 2] + cloud_speed * velocity.z).unit
            self.point_coordinates[i    ] = point.x
            self.point_coordinates[i + 1] = point.y
            self.point_coordinates[i + 2] = point.z
            self.point_coordinates[i + 3] = velocity.x
            self.point_coordinates[i + 4] = velocity.y
            self.point_coordinates[i + 5] = velocity.z

            self.point_coordinates[i + 6] += Float(dt)
        }

        self.point_mesh.replace_coordinates(with: self.point_coordinates)
    }

    func shade()
    {
        // globe
        glUseProgram(program: Shaders.vertcolor.program)
        glUniformMatrix4fv(Shaders.vertcolor.u_ids[0], 1, false, self.transform.model_matrix)
        //glBindVertexArray(array: self.field_mesh.VAO)
        //glDrawElements(GL_LINES, self.field_mesh.n, GL_UNSIGNED_INT, nil)

        glUseProgram(program: Shaders.globe.program)
        glUniformMatrix4fv(Shaders.globe.u_ids[0], 1, false, self.transform.model_matrix)
            // bind globe texture to location 0
        glUniform1i(Shaders.globe.tex_u_ids[0], 0)
        glActiveTexture(texture: GL_TEXTURE0)
        glBindTexture(GL_TEXTURE_CUBE_MAP, self.globe_tex.tex_id)

        glBindVertexArray(array: self.ball_mesh.VAO)
        glDrawElements(GL_TRIANGLES, self.ball_mesh.n, GL_UNSIGNED_INT, nil)

        // clouds
        glDisable(cap: GL_DEPTH_TEST)
        glBindVertexArray(array: self.point_mesh.VAO)

        glUseProgram(program: Shaders.cloudgen_shield.program)
        glUniformMatrix4fv(Shaders.cloudgen_shield.u_ids[0], 1, false, self.transform.model_matrix)
            // bind cloud texture to location 0
        glUniform1i(Shaders.cloudgen_shield.tex_u_ids[0], 0)
        glActiveTexture(texture: GL_TEXTURE0)
        glBindTexture(GL_TEXTURE_2D, self.cloud_tex_shield.tex_id)
        glDrawElements(GL_POINTS, self.point_mesh.n, GL_UNSIGNED_INT, nil)

        glUseProgram(program: Shaders.cloudgen_kernel.program)
        glUniformMatrix4fv(Shaders.cloudgen_kernel.u_ids[0], 1, false, self.transform.model_matrix)
            // bind cloud texture to location 0
        glUniform1i(Shaders.cloudgen_kernel.tex_u_ids[0], 0)
        glBindTexture(GL_TEXTURE_2D, self.cloud_tex_kernel.tex_id)
        glDrawElements(GL_POINTS, self.point_mesh.n, GL_UNSIGNED_INT, nil)

        glEnable(cap: GL_DEPTH_TEST)
        glBindVertexArray(array: 0)
    }

    private static
    func curl(at n:Vector3D<Double>, θ:Double = 0, bias:Double = 0, coriolis:Double = 1) -> Vector3D<Float>
    {
        let δ:Double = 0.0001,
            δ_inv:Double = 0.5/δ

        let tangent:Vector3D<Double>
        if n.x < n.y
        {
            //                                   x is the smallest        z is the smallest
            tangent = n.x < n.z ? Vector3D(0, -n.z, n.y) : Vector3D(-n.y, n.x, 0)
        }
        else
        {
            //                                   y is the smallest        z is the smallest
            tangent = n.y < n.z ? Vector3D(-n.z, 0, n.x) : Vector3D(-n.y, n.x, 0)
        }

        let u:Vector3D<Double> = tangent.unit,
            v:Vector3D<Double> = n.cross(u).unit

        let fu1:Double = FlowSphere.potential(n.x - δ*u.x, n.y - δ*u.y, n.z - δ*u.z, θ: θ),
            fu2:Double = FlowSphere.potential(n.x + δ*u.x, n.y + δ*u.y, n.z + δ*u.z, θ: θ),
            dfdu:Double = (fu2 - fu1) * δ_inv

        let fv1:Double = FlowSphere.potential(n.x - δ*v.x, n.y - δ*v.y, n.z - δ*v.z, θ: θ),
            fv2:Double = FlowSphere.potential(n.x + δ*v.x, n.y + δ*v.y, n.z + δ*v.z, θ: θ),
            dfdv:Double = (fv2 - fv1) * δ_inv

        return Vector3D<Float>(Float(coriolis * (v.x*dfdu - u.x*dfdv) + bias*(u.x*dfdu + v.x*dfdv)),
                               Float(coriolis * (v.y*dfdu - u.y*dfdv) + bias*(u.y*dfdu + v.y*dfdv)),
                               Float(coriolis * (v.z*dfdu - u.z*dfdv) + bias*(u.z*dfdu + v.z*dfdv)))
    }

}

struct View3D:GameScene
{
    private
    let fps_counter:Billboard,
        _cube:MeshResource

    private
    var _cloudvectors:FlowSphere,
        _advance:Bool = true

    private
    var render_mode:GLenum = GL_FILL,
        zoom_level:Int = 8,

        ball_anchor:BallView = BallView(ρ: 6.4),
        ball_view:BallView   = BallView(ρ: 6.4),
        uniform_camera:UniformCameraResource

    init(frame_width h:CInt, frame_height k:CInt)
    {
        self.uniform_camera = UniformCameraResource(h: Float(h), k: Float(k), size: 0.0001, z: 1, shift_x: 0, shift_y: 0)
        self.uniform_camera.update_view_matrix(ball: self.ball_view)
        self.uniform_camera.update_projection_matrix()

        self.fps_counter = Billboard(u: -1, v: 1, width: 300, height: -24, frame_width: h, frame_height: k)

        let cube_coords:[Float]  = [-0.5, -0.5, -0.5,   0, 0, 0,
                                    -0.5, -0.5,  0.5,   0, 0, 1,
                                    -0.5,  0.5, -0.5,   0, 1, 0,
                                    -0.5,  0.5,  0.5,   0, 1, 1,
                                     0.5, -0.5, -0.5,   1, 0, 0,
                                     0.5, -0.5,  0.5,   1, 0, 1,
                                     0.5,  0.5, -0.5,   1, 1, 0,
                                     0.5,  0.5,  0.5,   1, 1, 1]
        let cube_indices:[Int]   = [0, 4, 5,
                                    0, 5, 1,
                                    4, 6, 7,
                                    4, 7, 5,
                                    6, 2, 3,
                                    6, 3, 7,
                                    2, 0, 1,
                                    2, 1, 3,
                                    0, 2, 6,
                                    0, 6, 4,
                                    1, 5, 7,
                                    1, 7, 3]
        guard let cube_mesh = MeshResource(coordinates: cube_coords, indices: cube_indices, layout: [3, 3])
        else
        {
            fatalError("failed to make mesh")
        }
        self._cube = cube_mesh
        self._cloudvectors = FlowSphere(n: 12000, lifetime: 5)
    }

    func release_resources()
    {
        self._cube.release_resources()
        self.uniform_camera.release_resources()
    }

    func show3D(_ dt:Double)
    {
        self.uniform_camera.apply_camera()

        glEnable(cap: GL_CULL_FACE)
        glPolygonMode(GL_FRONT_AND_BACK, self.render_mode)

        if self._advance
        {
            self._cloudvectors.advance_points(dt: dt)
        }

        //self._cloudvectors.transform.rotate(by: Quaternion(Vector3D(0, 0, 1), Float(dt*0.1)))
        //self._cloudvectors.transform.update_matrices()
        self._cloudvectors.shade()

        // draw FPS counter
        self.fps_counter.clear()
        let cr = self.fps_counter.context
        cr.set_source_rgba(1, 1, 1, 1)
        cr.move_to(10, 20)
        cr.select_font_face(fontname: "Fira Mono", slant: CAIRO_FONT_SLANT_ITALIC, weight: CAIRO_FONT_WEIGHT_NORMAL)
        cr.set_font_size(13)
        cr.show_text("\(Int((1/dt).rounded())) FPS (render mode: \(self.render_mode == GL_FILL ? "faces" : "wireframe"))")
        self.fps_counter.update()
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
        self.fps_counter.shade()
    }

    mutating
    func on_resize(width h:CInt, height k:CInt)
    {
        self.fps_counter.rescale(frame_width: h, frame_height: k)
        self.uniform_camera.update_projection_matrix(h: Float(h), k: Float(k))
    }

    func start_drag(button:MouseButton) {}

    mutating
    func drag(x:CInt, y:CInt, x0:CInt, y0:CInt)
    {
        self.ball_view.θ = self.ball_anchor.θ - 0.005*Float(x - x0)
        self.ball_view.φ = max(0, min(Float.pi, self.ball_anchor.φ - 0.005*Float(y - y0)))

        self.uniform_camera.update_view_matrix(ball: self.ball_view)
    }

    mutating
    func end_drag()
    {
        self.ball_anchor = self.ball_view
    }

    mutating
    func scroll(axis:Bool, sign:Bool)
    {
        if axis
        {
            self.zoom_level = max(1, self.zoom_level + (sign ? -1 : 1))
            self.ball_view.ρ = 0.1*Float(self.zoom_level*self.zoom_level)

            self.uniform_camera.update_view_matrix(ball: self.ball_view)
        }
    }

    mutating
    func key(_ key:PhysicalKey)
    {
        switch key
        {
        case .tab:
            self.render_mode = self.render_mode == GL_FILL ? GL_LINE : GL_FILL
        case .space:
            self._advance = !self._advance
        default:
            return
        }
    }
}

/*
struct Planet_scene:Game_scene
{
    //var frame:Size2D  // the uniform camera holds this information

    //private
    //let planet:Planet,
    //    fps_counter:Billboard

    //private
    //var _axal_rot:Float = 0;

    private
    var camera_anchor:BallCoordinate = (0, 0, 0, 0, 0, 6.4),
        camera_ball:BallCoordinate   = (0, 0, 0, 0, 0, 6.4)

    //private
    //var uniform_camera:Camera_GPUmem

    private
    var zoom_level:Int = 8

    private
    var render_mode = GL_FILL

    init(frame:Size2D)
    {
        self.uniform_camera = create_uniform_camera(h: Float(frame.h), k: Float(frame.k), size: 0.0001, z: 1, shiftx: 0, shifty: 0)
        self.uniform_camera.calculate_view_matrix(ball: self.camera_ball)
        self.uniform_camera.calculate_projection_matrix()

        self.planet = Planet(radius: 1)
        self.fps_counter = Billboard(u: -1, v: 1, h: frame.h, k: frame.k, width:200, height:-24)
    }

    func scroll(axis:Bool, sign:Bool)
    {
        if axis
        {
            self.zoom_level = max(1, self.zoom_level + (sign ? -1 : 1))
            self.camera_ball.r = 0.1*Float(self.zoom_level*self.zoom_level)
        }
    }

    func start_drag(_ button:Int) {}
    func drag(_ p:IntCoordinate, from:IntCoordinate)
    {
        self.camera_ball.θ = self.camera_anchor.θ - 0.005*Float(p.x - from.x)
        self.camera_ball.φ = max(-Float.pi/2, min(Float.pi/2, self.camera_anchor.φ + 0.005*Float(p.y - from.y)))
    }
    func end_drag()
    {
        self.camera_anchor = self.camera_ball
    }

    func key(_ key:Int32)
    {
        switch key
        {
            case PhysicalKeys.TAB:
                self.render_mode = self.render_mode == GL_FILL ? GL_LINE : GL_FILL
                return
            case PhysicalKeys.LEFT:
                self.keyframes_x.insert((1, Double(self.camera_ball.x - 1), 0), at: 0)
            case PhysicalKeys.RIGHT:
                self.keyframes_x.insert((1, Double(self.camera_ball.x + 1), 0), at: 0)
            case PhysicalKeys.DOWN:
                self.camera_ball.y -= 1
            case PhysicalKeys.UP:
                self.camera_ball.y += 1
            default:
                return
        }
    }

    private
    func interpolate_keyframe_x(_ Δt:Double) -> Double
    {
        self.keyframe_x_progress += Δt
        assert(!self.keyframes_x.isEmpty) // the keyframe buffer will always have at least one keyframe (the depleted keyframe)
        var k:Int = self.keyframes_x.count - 2
        while k >= 0
        {
            if self.keyframe_x_progress >= self.keyframes_x[k].t
            {
                self.keyframe_x_progress -= self.keyframes_x[k].t
                k -= 1
            }
            else
            {
                break
            }
        }
        self.keyframes_x.removeLast(self.keyframes_x.count - k - 2)
        if k < 0
        {
            self.keyframe_x_progress = 0
            return self.keyframes_x[0].x // depleted queue
        }
        else
        {
            let next:Double = self.keyframes_x[k].x,
                base:Double = self.keyframes_x[k + 1].x // this should never fail

            let factor:Double = self.keyframe_x_progress / self.keyframes_x[k].t
            if let b = self.keyframes_x[k].quadratic_slope // quadratic interpolation
            {
                let a = next - base - b
                return base + b*factor + a*factor*factor
            }
            else // linear interpolation
            {
                return base + (next - base)*factor
            }
        }
    }

    func show3D(_ Δt:Double)
    {
        let x = self.interpolate_keyframe_x(Δt)

        self._axal_rot += Float(Δt*0.2)
        //self.planet.transform.rotate(by: Quaternion(Vector3D(0, 0, 1), Float(Δt*0.1)))
        //self.planet.transform.calculate_matrices()
        self.planet.transform = Transform(rotations: [Quaternion(Vector3D(0, 0, 1), self._axal_rot)])

        self.camera_ball.x = Float(x)

        self.uniform_camera.calculate_view_matrix(ball: self.camera_ball)

        glEnable(cap: GL_CULL_FACE)
        glPolygonMode(GL_FRONT_AND_BACK, self.render_mode)

        self.uniform_camera.set_camera()

        shade_planet(planet: self.planet)

        self.fps_counter.canvas.clear()
        let cr = self.fps_counter.canvas.cr
        cr.set_source_rgba(1, 1, 1, 1)
        cr.move_to(10, 20)
        cr.select_font_face(fontname: "Fira Mono", slant: CAIRO_FONT_SLANT_ITALIC, weight: CAIRO_FONT_WEIGHT_NORMAL)
        cr.set_font_size(13)
        cr.show_text("\(Int((1/Δt).rounded())) FPS")
        self.fps_counter.update()
        self.fps_counter.shade()
    }

    func on_resize(_ frame:Size2D)
    {
        self.uniform_camera.h = Float(frame.h)
        self.uniform_camera.k = Float(frame.k)
        self.uniform_camera.calculate_projection_matrix()

        self.fps_counter.rescale(h: frame.h, k: frame.k)
    }

    deinit
    {
        free_uniform_camera(self.uniform_camera)
    }
}
*/
