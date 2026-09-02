# Screenote image-comment skills

Updated the canonical Screenote feedback workflow and generated-host source to
the released CLI v0.4.0 contract. Feedback now exports root and reply
attachments beside each private crop and can attach one explicitly requested
or approved PNG, JPEG, or WebP image to a comment.

The contract probe, offline fixtures, mutation lint, and protected integration
cover both new flags. Ambiguous image-comment results stop without another
comment attempt, and unsupported image comments do not fall back to text-only
creation.
