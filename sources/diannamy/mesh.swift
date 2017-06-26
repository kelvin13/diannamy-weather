import OpenGL

struct MeshResource // we must always deallocate this from the GPU memory
{
    let n:GL.Size,
        k:Int

    let VBO:GL.UInt,
        EBO:GL.UInt,
        VAO:GL.UInt

    init?(coordinates:[Float], indices:[Int], layout:[Int])
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

        let coordinate_stride:GL.Size = GL.Size(m * MemoryLayout<Float>.size)

        var VAO:GL.UInt = 0
        glGenVertexArrays(n: 1, arrays: &VAO)
        glBindVertexArray(VAO)

        // create VBO
        var VBO:GL.UInt = 0
        glGenBuffers(n: 1, buffers: &VBO)
        glBindBuffer(target: GL.ARRAY_BUFFER, buffer: VBO)
        glBufferData(target: GL.ARRAY_BUFFER,
                     size  : GL.SizePointer(k * MemoryLayout<Float>.size),
                     data  : coordinates,
                     usage : GL.STATIC_DRAW)

        var offset:Int = 0
        for (i, l) in layout.enumerated()
        {
            glVertexAttribPointer(  index     : GL.UInt(i),
                                    size      : GL.Int(l),
                                    type      : GL.FLOAT,
                                    normalized: false,
                                    stride    : coordinate_stride,
                                    pointer   : UnsafeRawPointer(bitPattern: offset * MemoryLayout<Float>.size))
            glEnableVertexAttribArray(index: GL.UInt(i))
            offset += l
        }

        // Create EBO
        var EBO:GL.UInt = 0
        glGenBuffers(n: 1, buffers: &EBO)
        glBindBuffer(target: GL.ELEMENT_ARRAY_BUFFER, buffer: EBO)
        glBufferData(target: GL.ELEMENT_ARRAY_BUFFER,
                     size  : GL.SizePointer(n * MemoryLayout<GL.UInt>.size),
                     data  : indices.map{GL.UInt($0)}, // Int → UInt32
                     usage : GL.STATIC_DRAW)

        // unbind vertex array
        glBindVertexArray(0)
        // unbind buffers
        glBindBuffer(target: GL.ARRAY_BUFFER, buffer: 0)
        glBindBuffer(target: GL.ELEMENT_ARRAY_BUFFER, buffer: 0)

        self.n = GL.Size(n)
        self.k = k
        self.VBO = VBO
        self.EBO = EBO
        self.VAO = VAO
    }

    func replace_coordinates(with coordinates:[Float])
    {
        glBindBuffer(target: GL.ARRAY_BUFFER, buffer: self.VBO)
        glBufferSubData(GL.ARRAY_BUFFER, 0, max(self.k, coordinates.count) * MemoryLayout<Float>.size, coordinates)
        glBindBuffer(target: GL.ARRAY_BUFFER, buffer: 0)
    }

    func release_resources()
    {
        glDeleteBuffers(n: 2, buffers: [self.VBO, self.EBO])
        glDeleteVertexArrays(n: 1, arrays: [self.VAO])
    }
}
