import func Glibc.fopen
import func Glibc.fclose
import func Glibc.fseeko
import func Glibc.ftello
import func Glibc.fread
import func Glibc.rewind
import func Glibc.malloc
import func Glibc.free
import func Glibc.getenv
import typealias Glibc.FILE
import var Glibc.SEEK_END
import func Glibc.realpath

func posix_path(_ path:String) -> String
{
    guard let first_char:Character = path.characters.first
    else
    {
        return path
    }
    var expanded_path:String = path
    if first_char == "~"
    {
        if expanded_path.characters.count == 1 || expanded_path[expanded_path.index(expanded_path.startIndex, offsetBy: 1)] == "/"
        {
            expanded_path = String(cString: getenv("HOME")) + String(expanded_path.characters.dropFirst())
        }
    }
    return expanded_path
}

public func open_text_file(_ relative_path:String) -> String?
{
    let path:String = posix_path(relative_path)

    guard let f:UnsafeMutablePointer<FILE> = fopen(path, "rb")
    else
    {
        print("Error, could not open file '\(path)'")
        return nil
    }
    defer { fclose(f) }

    let fseek_status = fseeko(f, 0, SEEK_END)
    guard fseek_status == 0
    else
    {
        print("Error, fseeko() failed with error code \(fseek_status)")
        return nil
    }

    let n = ftello(f)
    guard 0..<CLong.max ~= n
    else
    {
        print("Error, ftello() returned file size outsize of allowed range")
        return nil
    }
    rewind(f)

    let buffer:UnsafeMutablePointer<CChar> = UnsafeMutablePointer<CChar>.allocate(capacity: n + 1) // leave room for sentinel
    defer { buffer.deallocate(capacity: n + 1) }

    let n_read = fread(buffer, MemoryLayout<CChar>.size, n, f)
    guard n_read == n
    else
    {
        print("Error, fread() read \(n_read) characters out of \(n)")
        return nil
    }

    buffer[n] = 0 // cap with sentinel
    return String(cString: buffer)
}
