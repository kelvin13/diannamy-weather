import SGLOpenGL

struct MeshResource // we must always deallocate this from the GPU memory
{
    let n:GLsizei,
        k:Int

    let VBO:GLuint,
        EBO:GLuint,
        VAO:GLuint

    init?(coordinates:[GLfloat], indices:[Int], layout:[Int])
    {
        guard layout.count <= 16
        else
        {
            print("Error: \(layout.count) attributes were given but most graphics cards only support up to 16")
            return nil
        }

        let n:Int = indices.count // number of indices
        let k:Int = coordinates.count // number of coordinates stored
        let m:Int = layout.reduce(0, +) // coordinates per point
        guard (k % m) == 0 && k > 0
        else
        {
            print("Error: \(k) coordinates were given, but \(k) is not divisible by \(m)-tuples")
            return nil
        }
        let p:Int = k/m // number of unique physical points defined

        /* validate indices */
        for index in indices
        {
            if index >= p
            {
                print("Error: indices contains value \(indices.max() ?? 0) but there are only \(p) points")
                return nil
            }
        }

        let coordinate_stride:GLsizei = GLsizei(m * MemoryLayout<GLfloat>.size)

        var VAO:GLuint = 0
        glGenVertexArrays(n: 1, arrays: &VAO)
        glBindVertexArray(array: VAO)

        // create VBO
        var VBO:GLuint = 0
        glGenBuffers(n: 1, buffers: &VBO)
        glBindBuffer(target: GL_ARRAY_BUFFER, buffer: VBO)
        glBufferData(target: GL_ARRAY_BUFFER,
                     size  : GLsizeiptr(k * MemoryLayout<GLfloat>.size),
                     data  : coordinates,
                     usage : GL_STATIC_DRAW)

        var offset:Int = 0
        for (i, l) in layout.enumerated()
        {
            glVertexAttribPointer(  index     : GLuint(i),
                                    size      : GLint(l),
                                    type      : GL_FLOAT,
                                    normalized: false,
                                    stride    : coordinate_stride,
                                    pointer   : UnsafeRawPointer(bitPattern: offset * MemoryLayout<GLfloat>.size))
            glEnableVertexAttribArray(index: GLuint(i))
            offset += l
        }

        // Create EBO
        var EBO:GLuint = 0
        glGenBuffers(n: 1, buffers: &EBO)
        glBindBuffer(target: GL_ELEMENT_ARRAY_BUFFER, buffer: EBO)
        glBufferData(target: GL_ELEMENT_ARRAY_BUFFER,
                     size  : GLsizeiptr(n * MemoryLayout<GLuint>.size),
                     data  : indices.map{GLuint($0)}, // Int → UInt32
                     usage : GL_STATIC_DRAW)

        // unbind vertex array
        glBindVertexArray(array: 0)
        // unbind buffers
        glBindBuffer(target: GL_ARRAY_BUFFER, buffer: 0)
        glBindBuffer(target: GL_ELEMENT_ARRAY_BUFFER, buffer: 0)

        self.n = GLsizei(n)
        self.k = k
        self.VBO = VBO
        self.EBO = EBO
        self.VAO = VAO
    }

    func replace_coordinates(with coordinates:[Float])
    {
        glBindBuffer(target: GL_ARRAY_BUFFER, buffer: self.VBO)
        glBufferSubData(GL_ARRAY_BUFFER, 0, max(self.k, coordinates.count)*MemoryLayout<GLfloat>.size, coordinates)
        glBindBuffer(target: GL_ARRAY_BUFFER, buffer: 0)
    }

    func release_resources()
    {
        glDeleteBuffers(n: 2, buffers: [self.VBO, self.EBO])
        glDeleteVertexArrays(n: 1, arrays: [self.VAO])
    }
}
