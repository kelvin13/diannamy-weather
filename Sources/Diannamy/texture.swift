import SGLOpenGL

struct Texture2DResource
{
    enum Format
    {
    case quad_bytes,
         triple_bytes,
         double_bytes,
         single_bytes,
         rgba_per_int32,
         argb_per_int32

        var format_code:GLenum
        {
            switch self
            {
            case .quad_bytes, .rgba_per_int32:
                return GL_RGBA
            case .argb_per_int32:
                return GL_BGRA
            case .triple_bytes:
                return GL_RGB
            case .double_bytes:
                return GL_RG
            case .single_bytes:
                return GL_RED
            }
        }

        var layout_code:GLenum
        {
            switch self
            {
            case .quad_bytes, .triple_bytes, .double_bytes, .single_bytes:
                return GL_UNSIGNED_BYTE
            case .rgba_per_int32:
                return GL_UNSIGNED_INT_8_8_8_8
            case .argb_per_int32:
                return GL_UNSIGNED_INT_8_8_8_8_REV
            }
        }

        var internal_code:GLenum
        {
            switch self
            {
            case .quad_bytes, .rgba_per_int32, .argb_per_int32:
                return GL_RGBA
            case .triple_bytes:
                return GL_RGB
            case .double_bytes:
                return GL_RG
            case .single_bytes:
                return GL_RED
            }
        }
    }

    let tex_id:GLuint

    private
    let format:Format,
        width :CInt,
        height:CInt

    init(pixbuf:UnsafeBufferPointer<UInt8>, width h:CInt, height k:CInt, format:Format, linear:Bool = true)
    {
        var tex_id:GLuint = 0
        glGenTextures(1, &tex_id)
        glBindTexture(GL_TEXTURE_2D, tex_id)
        glTexImage2D(target         : GL_TEXTURE_2D,
                     level          : 0,
                     internalformat : format.internal_code,
                     width          : h,
                     height         : k,
                     border         : 0,
                     format         : format.format_code,
                     type           : format.layout_code,
                     pixels         : UnsafeRawPointer(pixbuf.baseAddress!))
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, linear ? GL_LINEAR : GL_NEAREST)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, linear ? GL_LINEAR : GL_NEAREST)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

        glBindTexture(GL_TEXTURE_2D, 0)

        self.tex_id = tex_id
        self.format = format
        self.width  = h
        self.height = k
    }

    func release_resources()
    {
        glDeleteTextures(1, [self.tex_id])
    }

    mutating
    func update_texture(pixbuf:UnsafeBufferPointer<UInt8>)
    {
        glBindTexture(GL_TEXTURE_2D, self.tex_id)
        glTexSubImage2D(target         : GL_TEXTURE_2D,
                     level          : 0,
                     xoffset        : 0,
                     yoffset        : 0,
                     width          : self.width,
                     height         : self.height,
                     format         : self.format.format_code,
                     type           : self.format.layout_code,
                     pixels         : UnsafeRawPointer(pixbuf.baseAddress!))
        glBindTexture(GL_TEXTURE_2D, 0)
    }
}


/*
struct Cube_textures_GPUmem
{
    let tex_ids:[GLuint]
}

func create_cube_textures(_ cubes:CubemapData...) -> Cube_textures_GPUmem
{
    let n:Int
    if cubes.count > 16
    {
        print("warning, more than 16 cube textures were passed")
        n = 16
    }
    else
    {
        n = cubes.count
    }

    var tex_ids = [GLuint](repeating: 0, count: n)
    glGenTextures(GLsizei(n), &tex_ids)

    for (tex_id, cube) in zip(tex_ids, cubes)
    {
        glBindTexture(GL_TEXTURE_CUBE_MAP, tex_id)
        assert(cube.cubemaps.count == 6) // this should already be guaranteed by its constructor
        let format:GLenum
        switch cube.format
        {
            case .RGB:
                format = GL_RGB
            case .RGBA:
                format = GL_RGBA
            case .grayscale:
                format = GL_RED
        }
        for (i, face) in cube.cubemaps.enumerated()
        {
            glTexImage2D(target         : GL_TEXTURE_CUBE_MAP_POSITIVE_X + GLint(i),
                         level          : 0,
                         internalformat : format,
                         width          : cube.size.h32,
                         height         : cube.size.k32,
                         border         : 0,
                         format         : format,
                         type           : GL_UNSIGNED_BYTE,
                         pixels         : face)
        }

        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE)

    }
    glBindTexture(GL_TEXTURE_CUBE_MAP, 0)
    return Cube_textures_GPUmem(tex_ids: tex_ids)
}

func free_cube_textures(_ cube_textures:Cube_textures_GPUmem)
{
    glDeleteTextures(GLsizei(cube_textures.tex_ids.count), cube_textures.tex_ids)
}
*/
