import SGLOpenGL

import MaxPNG

enum TextureFormat
{
case quad_bytes,
     triple_bytes,
     double_bytes,
     single_bytes,
     quad_shorts,
     triple_shorts,
     double_shorts,
     single_shorts,
     rgba_per_int32,
     argb_per_int32

    var format_code:GLenum
    {
        switch self
        {
        case .quad_bytes, .quad_shorts, .rgba_per_int32:
            return GL_RGBA
        case .argb_per_int32:
            return GL_BGRA
        case .triple_bytes, .triple_shorts:
            return GL_RGB
        case .double_bytes, .double_shorts:
            return GL_RG
        case .single_bytes, .single_shorts:
            return GL_RED
        }
    }

    var layout_code:GLenum
    {
        switch self
        {
        case .quad_bytes, .triple_bytes, .double_bytes, .single_bytes:
            return GL_UNSIGNED_BYTE
        case .quad_shorts, .triple_shorts, .double_shorts, .single_shorts:
            return GL_UNSIGNED_SHORT
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
            return GL_RGBA8
        case .triple_bytes:
            return GL_RGB8
        case .double_bytes:
            return GL_RG8
        case .single_bytes:
            return GL_R8
        case .quad_shorts:
            return GL_RGBA16
        case .triple_shorts:
            return GL_RGB16
        case .double_shorts:
            return GL_RG16
        case .single_shorts:
            return GL_R16
        }
    }
}

struct Bitmap
{
    let format:TextureFormat,
        width:CInt,
        height:CInt,
        pixbytes:[UInt8]

    init?(png path:String)
    {
        let pixbuf:[UInt8],
            properties:PNGProperties
        do
        {
            try (pixbuf, properties) = png_decode(path: path)
        }
        catch
        {
            print(error)
            return nil
        }

        let format:TextureFormat
        if properties.bit_depth == 8
        {
            switch properties.color
            {
            case .rgba:
                format = .quad_bytes
            case .rgb, .indexed:
                format = .triple_bytes
            case .grayscale_a:
                format = .double_bytes
            case .grayscale:
                format = .single_bytes
            }
        }
        else
        {
            switch properties.color
            {
            case .rgba:
                format = .quad_shorts
            case .rgb, .indexed:
                format = .triple_shorts
            case .grayscale_a:
                format = .double_shorts
            case .grayscale:
                format = .single_shorts
            }
        }

        guard let deinterlaced_pixbuf:[UInt8] = properties.interlaced ? properties.deinterlace(raw_data: pixbuf) : pixbuf
        else
        {
            return nil
        }

        guard let pixbytes = properties.expand(raw_data: deinterlaced_pixbuf)
        else
        {
            return nil
        }

        self.format = format
        self.width  = CInt(properties.width)
        self.height = CInt(properties.height)
        self.pixbytes = pixbytes
    }

    func upload(target:GLenum)
    {
        glTexImage2D(target         : target,
                     level          : 0,
                     internalformat : self.format.internal_code,
                     width          : self.width,
                     height         : self.height,
                     border         : 0,
                     format         : self.format.format_code,
                     type           : self.format.layout_code,
                     pixels         : self.pixbytes)
    }
}

struct Texture2DResource
{
    let tex_id:GLuint

    init?(png path:String, linear:Bool = true)
    {
        guard let bitmap:Bitmap = Bitmap(png: path)
        else
        {
            return nil
        }

        self.init(bitmap: bitmap, linear: linear)
    }

    init(bitmap:Bitmap, linear:Bool = true)
    {
        var tex_id:GLuint = 0
        glGenTextures(1, &tex_id)
        glBindTexture(GL_TEXTURE_2D, tex_id)

        bitmap.upload(target: GL_TEXTURE_2D)

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, linear ? GL_LINEAR : GL_NEAREST)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, linear ? GL_LINEAR : GL_NEAREST)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

        glBindTexture(GL_TEXTURE_2D, 0)

        self.tex_id = tex_id
    }

    func release_resources()
    {
        glDeleteTextures(1, [self.tex_id])
    }
}

struct StreamableTexture2DResource
{
    let tex_id:GLuint

    private
    let format:TextureFormat,
        width :CInt,
        height:CInt

    init(pixbuf:UnsafeBufferPointer<UInt8>, width h:CInt, height k:CInt, format:TextureFormat, linear:Bool = true)
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
                     pixels         : pixbuf.baseAddress)
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
                     pixels         : pixbuf.baseAddress)
        glBindTexture(GL_TEXTURE_2D, 0)
    }
}

struct CubeTextureResource
{
    let tex_id:GLuint

    init?(bitmaps:[Bitmap], linear:Bool = true)
    {
        guard bitmaps.count == 6
        else
        {
            print("need 6 cube textures, only got \(bitmaps.count)")
            return nil
        }

        for bitmap in bitmaps
        {
            guard bitmap.width == bitmaps[0].width, bitmap.height == bitmaps[0].height, bitmap.format == bitmaps[0].format
            else
            {
                return nil
            }
        }

        var tex_id:GLuint = 0
        glGenTextures(1, &tex_id)
        glBindTexture(GL_TEXTURE_CUBE_MAP, tex_id)
        for (i, bitmap) in bitmaps.enumerated()
        {
            bitmap.upload(target: GL_TEXTURE_CUBE_MAP_POSITIVE_X + GLint(i))
        }

        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, linear ? GL_LINEAR : GL_NEAREST)
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, linear ? GL_LINEAR : GL_NEAREST)
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE)

        glBindTexture(GL_TEXTURE_CUBE_MAP, 0)
        self.tex_id = tex_id
    }

    init?(png_pattern:String, linear:Bool = true)
    {
        var bitmaps:[Bitmap] = []
            bitmaps.reserveCapacity(6)
        for i in 0 ..< 6
        {
            guard let bitmap:Bitmap = Bitmap(png: "\(png_pattern)_\(i).png")
            else
            {
                return nil
            }

            bitmaps.append(bitmap)
        }

        self.init(bitmaps: bitmaps, linear: linear)
    }

    func release_resources()
    {
        glDeleteTextures(1, [self.tex_id])
    }
}
