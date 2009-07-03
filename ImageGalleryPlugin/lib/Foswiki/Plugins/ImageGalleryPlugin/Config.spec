# ---+ Extensions
# ---++ ImageGalleryPlugin
# This is the configuration used by the <b>ImageGalleryPlugin</b>.

# **PERL**
# Defintion of thumbnailsizes 
$Foswiki::cfg{ImageGalleryPlugin}{ThumbSizes} = {
    thin => '25x25',
    small => '50x50',
    medium=> '95x95',
    large => '150x150',
    huge => '250x250',
};

# **STRING**
# A pattern of filetype suffixes to be excluded from imagegalleries even though they are 
# valid images
$Foswiki::cfg{ImageGalleryPlugin}{ExcludeSuffix} = 'psd';

# **SELECT Image::Magick,Graphics::Magick**
# Select the image processing backend. Image::Magick and Graphics::Magick are mostly compatible
# as far as they are used here.
$Foswiki::cfg{ImageGalleryPlugin}{Impl} = 'Image::Magick';

