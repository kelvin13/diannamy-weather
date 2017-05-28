import SGLOpenGL
import Geometry

struct UniformCameraResource
{
    let matrix_buffer:GLuint

    private
    var projection_matrix:[Float] = [],
        view_matrix:[Float] = [],

        position:Vector3D<Float>,

        h:Float,
        k:Float,
        size:Float,
        z:Float,
        shift_x:Float,
        shift_y:Float

    init(h:Float, k:Float, size:Float, z:Float, shift_x:Float, shift_y:Float)
    {
        var matrix_buffer:GLuint = 0
        glGenBuffers(1, &matrix_buffer)
        glBindBuffer(GL_UNIFORM_BUFFER, matrix_buffer)
        // allocate space for the buffer
        glBufferData(GL_UNIFORM_BUFFER, 168, nil, GL_DYNAMIC_DRAW)
        // bind camera buffer to position 0
        glBindBufferBase(GL_UNIFORM_BUFFER, 0, matrix_buffer)
        glBindBuffer(GL_UNIFORM_BUFFER, 0)

        self.matrix_buffer = matrix_buffer
        self.position      = Vector3D<Float>(0, 0, 0)
        self.h             = h
        self.k             = k
        self.size          = size
        self.z             = z
        self.shift_x       = shift_x
        self.shift_y       = shift_y

        self.update_projection_matrix()
    }

    func release_resources()
    {
        glDeleteBuffers(1, [self.matrix_buffer])
    }

    mutating
    func update_projection_matrix(h:Float, k:Float)
    {
        // frustum
        let f_width:Float  = h * self.size,
            f_height:Float = k * self.size,
            dx:Float       = -2*self.shift_x / h,
            dy:Float       = -2*self.shift_y / k

        let _clip:Float    = 1000
        self.projection_matrix =
        [self.z/f_width , 0              , 0                            , 0,
         0              , self.z/f_height, 0                            , 0,
         dx             , dy             ,    (1 + _clip) / (1 - _clip) ,-1,
         0              , 0              , self.z*2*_clip / (1 - _clip) , 0]
    }

    mutating
    func update_projection_matrix()
    {
        self.update_projection_matrix(h: self.h, k: self.k)
    }

    mutating
    func update_view_matrix(ball:BallView)
    {
        (self.position, self.view_matrix) = ball.position_and_view_matrix
    }

    func apply_camera()
    {
        glBindBuffer(GL_UNIFORM_BUFFER, self.matrix_buffer)
        glBufferSubData(GL_UNIFORM_BUFFER, 0, 64, self.projection_matrix)
        glBufferSubData(GL_UNIFORM_BUFFER, 64, 64, self.view_matrix)
        glBufferSubData(GL_UNIFORM_BUFFER, 128, 12, [self.position.x, self.position.y, self.position.z])
        glBufferSubData(GL_UNIFORM_BUFFER, 144, 24, [0.5*self.h, 0.5*self.k, 2*self.size, self.z, self.shift_x, self.shift_y])
        glBindBuffer(GL_UNIFORM_BUFFER, 0)
    }
}
